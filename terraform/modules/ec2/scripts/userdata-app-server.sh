#!/bin/bash
set -euo pipefail

PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"

echo "=== [userdata-app-server] wepick app server bootstrap start ==="

# 패키지 업데이트
apt-get update -y
apt-get upgrade -y

# Docker 공식 레포 추가 및 설치
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# SSM Agent 설치 (Ubuntu는 기본 내장 아님)
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent

# AWS CLI 설치 (ARM64)
apt-get install -y unzip
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# certbot 설치 (Let's Encrypt)
apt-get install -y certbot python3-certbot-nginx

# 앱 디렉토리 생성
mkdir -p /srv/wepick
chown ubuntu:ubuntu /srv/wepick

echo "=== [userdata-app-server] bootstrap complete ==="
