#!/bin/bash
apt update -y

# install docker
apt install -y docker.io docker-compose
systemctl start docker
systemctl enable docker

# allow ubuntu user use docker
usermod -aG docker ubuntu

# run jenkins
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts

# run harbor
docker run -d \
  --name harbor \
  -p 80:80 \
  -p 443:443 \
  -p 5000:5000 \
  -e HARBOR_ADMIN_PASSWORD=Thu4n@th3n \
  -v harbor_data:/data \
  -v harbor_config:/etc/harbor \
  goharbor/harbor-all:latest