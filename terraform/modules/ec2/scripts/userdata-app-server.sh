#!/bin/bash
set -euo pipefail

PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"

echo "=== [userdata-app-server] wepick app server bootstrap start ==="

# 패키지 업데이트
apt-get update -y
apt-get upgrade -y

# Docker 공식 레포 추가 및 설치
apt-get install -y ca-certificates curl gnupg gettext-base
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

# SSM Agent
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent

# AWS CLI (ARM64)
apt-get install -y unzip
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# certbot (nginx 플러그인 미설치 — docker compose nginx와 80/443 포트 충돌 방지)
apt-get install -y certbot

# 앱 디렉토리
mkdir -p /srv/wepick
chown ubuntu:ubuntu /srv/wepick

# certbot renew systemd timer
cat > /etc/systemd/system/certbot-renew.service <<'EOF'
[Unit]
Description=Certbot renewal
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --post-hook "docker exec wepick_nginx nginx -s reload || true"
EOF

cat > /etc/systemd/system/certbot-renew.timer <<'EOF'
[Unit]
Description=Daily certbot renewal

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now certbot-renew.timer

echo "=== [userdata-app-server] bootstrap complete ==="
