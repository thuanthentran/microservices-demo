#!/bin/bash
set -euo pipefail

# ============================================================================
# Logging Setup
# ============================================================================

LOG_FILE="/var/log/harbor-jenkins-setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log_timestamp() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_info() {
  log_timestamp "ℹ️  INFO: $*"
}

log_success() {
  log_timestamp "✓ SUCCESS: $*"
}

log_error() {
  log_timestamp "❌ ERROR: $*"
}

log_separator() {
  log_timestamp "========================================"
}

log_separator
log_info "Starting Jenkins and Harbor installation script"
log_info "Log file: $LOG_FILE"
log_separator

# Error handling function
handle_error() {
  log_error "Error occurred at line $1"
  log_separator
  exit 1
}

trap 'handle_error $LINENO' ERR

# Harbor Configuration Variables
HARBOR_HOSTNAME="${harbor_hostname}"
HARBOR_PASSWORD="${harbor_admin_password}"
HARBOR_EMAIL="${harbor_admin_email}"
HARBOR_HTTPS_PORT="${harbor_https_port}"
HARBOR_HTTP_PORT="${harbor_http_port}"
HARBOR_SSL_COUNTRY="${harbor_ssl_cert_country}"
HARBOR_SSL_STATE="${harbor_ssl_cert_state}"
HARBOR_SSL_CITY="${harbor_ssl_cert_city}"
HARBOR_SSL_ORG="${harbor_ssl_cert_organization}"

log_info "Configuration loaded:"
log_info "  Harbor Hostname: $HARBOR_HOSTNAME"
log_info "  Harbor HTTPS Port: $HARBOR_HTTPS_PORT"
log_info "  Harbor HTTP Port: $HARBOR_HTTP_PORT"

log_info "Updating package manager..."
apt update -y

# install docker
log_info "Installing Docker..."
apt install -y docker.io docker-compose
log_success "Docker and docker-compose installed"

log_info "Starting Docker service..."
systemctl start docker
systemctl enable docker
log_success "Docker service started and enabled"

# allow azureuser to use docker without sudo
log_info "Adding azureuser to docker group..."
usermod -aG docker azureuser 2>/dev/null || log_error "Could not add azureuser to docker group"
log_success "azureuser added to docker group"

# run jenkins
log_info "Starting Jenkins container..."
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -u root \
  jenkins/jenkins:lts

log_success "Jenkins container started on port 8080"
log_info "Jenkins can now access Docker via socket mount"

# wait for jenkins to be ready
log_info "Waiting for Jenkins to be ready (2 minutes)..."
sleep 120

# wait for jenkins to actually be ready
log_info "Waiting for Jenkins daemon to respond..."
RETRY_COUNT=0
MAX_RETRIES=30
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker exec jenkins bash -c 'test -f /var/jenkins_home/config.xml' 2>/dev/null; then
    log_success "Jenkins is ready!"
    break
  fi
  RETRY_COUNT=$(( RETRY_COUNT + 1 ))
  log_info "  Retry ($RETRY_COUNT/$MAX_RETRIES)..."
  sleep 2
done

# install docker cli in jenkins container (optional, best effort)
log_info "Installing Docker CLI in Jenkins container (optional)..."
if docker exec jenkins bash -c 'apt-get update && apt-get install -y docker.io' 2>/dev/null; then
  log_success "Docker CLI installed in Jenkins"
else
  log_info "Docker CLI installation skipped (using socket mount)"
fi

# verify docker access (optional)
log_info "Verifying Docker access in Jenkins container..."
docker exec jenkins docker ps > /dev/null 2>&1 && log_success "Docker accessible from Jenkins" || log_info "Docker access verification skipped"
# Generate self-signed SSL certificates for Harbor
log_separator
log_info "Generating Harbor SSL certificates..."
openssl genrsa -out ca.key 4096
log_info "Generated CA private key"

openssl req -x509 -new -nodes -sha512 -days 3650 \
-subj "/C=$HARBOR_SSL_COUNTRY/ST=$HARBOR_SSL_STATE/L=$HARBOR_SSL_CITY/O=$HARBOR_SSL_ORG/CN=$HARBOR_HOSTNAME" \
-key ca.key \
-out ca.crt
log_success "Generated CA certificate"

openssl genrsa -out $HARBOR_HOSTNAME.key 4096

openssl req -sha512 -new \
-subj "/C=$HARBOR_SSL_COUNTRY/ST=$HARBOR_SSL_STATE/L=$HARBOR_SSL_CITY/O=$HARBOR_SSL_ORG/CN=$HARBOR_HOSTNAME" \
-key $HARBOR_HOSTNAME.key \
-out $HARBOR_HOSTNAME.csr

cat > v3.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage=serverAuth

subjectAltName=@alt_names

[alt_names]
DNS.1=$HARBOR_HOSTNAME
DNS.2=localhost
EOF

# If Harbor hostname is an IPv4 address, include it as IP SAN as well.
if [[ "$HARBOR_HOSTNAME" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "IP.1=$HARBOR_HOSTNAME" >> v3.ext
fi

openssl x509 -req -sha512 -days 3650 \
-extfile v3.ext \
-CA ca.crt -CAkey ca.key -CAcreateserial \
-in $HARBOR_HOSTNAME.csr \
-out $HARBOR_HOSTNAME.crt

mkdir -p /data/cert 

cp $HARBOR_HOSTNAME.crt /data/cert/
cp $HARBOR_HOSTNAME.key /data/cert/
cp ca.crt /data/cert/

openssl x509 -inform PEM \
-in $HARBOR_HOSTNAME.crt \
-out $HARBOR_HOSTNAME.cert

DOCKER_CERTS_DIR="/etc/docker/certs.d/$HARBOR_HOSTNAME"
mkdir -p "$DOCKER_CERTS_DIR"

cp $HARBOR_HOSTNAME.cert "$DOCKER_CERTS_DIR/"
cp $HARBOR_HOSTNAME.key "$DOCKER_CERTS_DIR/"
cp ca.crt "$DOCKER_CERTS_DIR/"

# Configure Docker daemon before Harbor install so no daemon restart is needed afterward.
cat > /etc/docker/daemon.json << DOCKER_CONFIG
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DOCKER_CONFIG

systemctl restart docker

echo "SSL certificates generated at /data/cert/"
log_success "Harbor SSL certificates generated"
log_separator

# install harbor
log_info "Installing Harbor dependencies..."
sudo apt install unzip curl -y
log_success "Harbor dependencies installed"

# download and extract harbor
cd /tmp
log_info "Downloading Harbor v2.8.2..."
wget https://github.com/goharbor/harbor/releases/download/v2.8.2/harbor-online-installer-v2.8.2.tgz && log_info "Downloaded Harbor" || log_error "Failed to download Harbor"
log_info "Extracting Harbor..."
tar xzvf harbor-online-installer-v2.8.2.tgz && log_success "Harbor extracted" || log_error "Failed to extract Harbor"
cd harbor

# configure harbor.yml
log_info "Configuring Harbor configuration file..."
cp harbor.yml.tmpl harbor.yml

# update harbor configuration with values from Terraform
sed -i "s/^hostname: .*/hostname: $HARBOR_HOSTNAME/" harbor.yml
sed -i "s/^harbor_admin_password: .*/harbor_admin_password: $HARBOR_PASSWORD/" harbor.yml

# Also set email if needed
sed -i "s/^email_server\.email_from: .*/email_server.email_from: $HARBOR_EMAIL/" harbor.yml

# enable https in harbor.yml
sed -i 's|port: 443|port: '"$HARBOR_HTTPS_PORT"'|' harbor.yml
sed -i 's|certificate: .*|certificate: /data/cert/'$HARBOR_HOSTNAME'.crt|' harbor.yml
sed -i 's|private_key: .*|private_key: /data/cert/'$HARBOR_HOSTNAME'.key|' harbor.yml

# Update HTTP port
sed -i 's|^http:|&\n  port: '"$HARBOR_HTTP_PORT"'|' harbor.yml

echo "Harbor configuration completed"
echo "  Hostname: $HARBOR_HOSTNAME"
echo "  HTTPS Port: $HARBOR_HTTPS_PORT"
echo "  HTTP Port: $HARBOR_HTTP_PORT"

# install and start harbor
log_separator
log_info "Installing Harbor with Trivy scanning..."
chmod +x install.sh
sudo ./install.sh --with-trivy && log_success "Harbor installed successfully" || log_error "Harbor installation failed"

# Re-run compose to make sure Harbor services are up even if prior steps were interrupted.
sudo docker compose -f /tmp/harbor/docker-compose.yml up -d && log_success "Harbor services are running"

# Update CA certificates in Jenkins container
log_info "Updating CA certificates in Jenkins container..."
docker exec jenkins update-ca-certificates 2>/dev/null && log_success "Jenkins CA certificates updated" || log_info "update-ca-certificates may need additional setup"

# Restart Jenkins to apply certificate changes
log_info "Restarting Jenkins to apply certificate changes..."
docker restart jenkins && log_success "Jenkins restarted" || log_error "Failed to restart Jenkins"

if curl -s --cacert /data/cert/ca.crt https://$HARBOR_HOSTNAME:$HARBOR_HTTPS_PORT/api/v2.0/health >/dev/null 2>&1; then
  log_success "Harbor HTTPS connectivity verified"
else
  log_info "Harbor HTTPS connectivity test failed - may need manual certificate configuration"
fi

if echo "$HARBOR_PASSWORD" | docker login -u admin --password-stdin https://$HARBOR_HOSTNAME:$HARBOR_HTTPS_PORT 2>/dev/null; then
  log_success "Docker login to Harbor successful"
else
  log_info "Docker login test failed - verify certificate is properly trusted"
fi

log_separator
log_success "Installation completed successfully"
log_info "Jenkins: http://<your-vm-ip>:8080"
log_info "Harbor: https://<your-vm-ip>:$HARBOR_HTTPS_PORT"
log_info "Harbor Admin User: admin"