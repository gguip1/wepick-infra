#!/bin/bash
set -euo pipefail

PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"

echo "=== [userdata-app-server] wepick app server bootstrap start ==="

# 패키지 업데이트 및 Docker 설치
dnf update -y
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# docker compose v2 플러그인 설치 (ARM64)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# SSM Agent 확인 (Amazon Linux 2023 기본 내장)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# certbot 설치 (Let's Encrypt)
dnf install -y python3-pip augeas-libs
pip3 install certbot certbot-nginx

# 앱 디렉토리 생성
mkdir -p /srv/wepick
chown ec2-user:ec2-user /srv/wepick

# ghcr.io 로그인 (Parameter Store에서 토큰 취득)
GHCR_TOKEN=$(aws ssm get-parameter \
  --name "/$PROJECT_NAME/ghcr_token" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -n "$GHCR_TOKEN" ]; then
  GHCR_USER=$(aws ssm get-parameter \
    --name "/$PROJECT_NAME/ghcr_user" \
    --query "Parameter.Value" \
    --output text \
    --region "$AWS_REGION")
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
  echo "ghcr.io login succeeded"
else
  echo "WARNING: ghcr.io token not found in Parameter Store — skipping login"
fi

echo "=== [userdata-app-server] bootstrap complete ==="
