#!/bin/bash
set -e

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

echo "=========================================="
echo "Installing Jenkins and Harbor"
echo "=========================================="

apt update -y

# install docker
echo "Installing Docker..."
apt install -y docker.io docker-compose
systemctl start docker
systemctl enable docker

# allow ubuntu user use docker
usermod -aG docker ubuntu

# run jenkins
echo "Starting Jenkins..."
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -u root \
  jenkins/jenkins:lts

echo "Jenkins started on port 8080"
echo "Jenkins can now access Docker from the host"

# wait for jenkins to be ready
echo "Waiting for Jenkins to be ready (30 seconds)..."
sleep 30

# install docker cli in jenkins container
echo "Installing Docker CLI in Jenkins container..."
docker exec jenkins bash -c '
  apt-get update
  apt-get install -y docker.io
' || echo "Note: Docker CLI installation in container failed, but docker socket is mounted"

# verify docker access
echo "Verifying Docker access in Jenkins container..."
docker exec jenkins docker ps || echo "Docker access verification skipped"

# install harbor
echo "Installing Harbor..."
apt install unzip curl -y

# download and extract harbor
cd /tmp
echo "Downloading Harbor v2.8.2..."
wget https://github.com/goharbor/harbor/releases/download/v2.8.2/harbor-online-installer-v2.8.2.tgz
tar xzvf harbor-online-installer-v2.8.2.tgz
cd harbor

# generate ssl certificates
echo "Generating SSL certificates..."
mkdir -p /data/cert
openssl req -newkey rsa:2048 -nodes \
  -keyout /data/cert/server.key \
  -x509 -days 365 -out /data/cert/server.crt \
  -subj "/C=$${HARBOR_SSL_COUNTRY}/ST=$${HARBOR_SSL_STATE}/L=$${HARBOR_SSL_CITY}/O=$${HARBOR_SSL_ORG}/CN=$${HARBOR_HOSTNAME}"

echo "SSL certificates generated at /data/cert/"

# configure harbor.yml
echo "Configuring Harbor..."
cp harbor.yml.tmpl harbor.yml

# update harbor configuration with values from Terraform
sed -i "s/^hostname: .*/hostname: $${HARBOR_HOSTNAME}/" harbor.yml
sed -i "s/^harbor_admin_password: .*/harbor_admin_password: $${HARBOR_PASSWORD}/" harbor.yml

# Also set email if needed
sed -i "s/^email_server\.email_from: .*/email_server.email_from: $${HARBOR_EMAIL}/" harbor.yml

# enable https in harbor.yml
sed -i 's|^  port: 443|  port: '"$${HARBOR_HTTPS_PORT}"'|' harbor.yml
sed -i 's|^  ssl_cert: .*|  ssl_cert: /data/cert/server.crt|' harbor.yml
sed -i 's|^  ssl_cert_key: .*|  ssl_cert_key: /data/cert/server.key|' harbor.yml

# Update HTTP port
sed -i 's|^http:|&\n  port: '"$${HARBOR_HTTP_PORT}"'|' harbor.yml

echo "Harbor configuration completed"
echo "  Hostname: $${HARBOR_HOSTNAME}"
echo "  HTTPS Port: $${HARBOR_HTTPS_PORT}"
echo "  HTTP Port: $${HARBOR_HTTP_PORT}"

# install and start harbor
echo "Installing Harbor with Trivy..."
chmod +x install.sh
sudo ./install.sh --with-trivy

echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo "Jenkins: http://<your-vm-ip>:8080"
echo "Harbor: https://<your-vm-ip>:$${HARBOR_HTTPS_PORT}"
echo "Harbor Admin User: admin"
echo "Harbor Admin Password: [HIDDEN]"

