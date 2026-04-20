#!/bin/bash
# SSM SendCommand가 EC2에서 실행하는 배포 스크립트.
# 사용법: deploy-on-ec2.sh <service>
#   service: backend | frontend | nginx | mysql | all
# 환경변수:
#   DRY_RUN=1 — 실제 명령은 실행하지 않고 출력만
set -euo pipefail

SERVICE="${1:-all}"
AWS_REGION="ap-northeast-2"
PROJECT_NAME="wepick"
APP_DIR="/srv/wepick"
ARTIFACTS_BUCKET="${ARTIFACTS_BUCKET:-}"

run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: $*"
  else
    eval "$@"
  fi
}

if [[ -z "$ARTIFACTS_BUCKET" ]]; then
  ARTIFACTS_BUCKET=$(aws ssm get-parameter --name "/${PROJECT_NAME}/artifacts_bucket" --query "Parameter.Value" --output text --region "$AWS_REGION")
fi

echo "=== [deploy-on-ec2] service=$SERVICE bucket=$ARTIFACTS_BUCKET ==="

# 1. 작업 디렉토리 보장 + S3 동기화
run "mkdir -p $APP_DIR && chown ubuntu:ubuntu $APP_DIR"
run "aws s3 sync s3://$ARTIFACTS_BUCKET/prod/ $APP_DIR/ --delete --region $AWS_REGION"

# 2. Parameter Store → .env 생성
ENV_FILE="$APP_DIR/.env"
run "aws ssm get-parameters-by-path --path /${PROJECT_NAME}/ --with-decryption --region $AWS_REGION \
  --query 'Parameters[].[Name,Value]' --output text \
  | awk -F'\\t' '{ n=\$1; sub(\"^/${PROJECT_NAME}/\",\"\",n); if (n !~ /[/.-]/) printf \"%s=%s\\n\", toupper(n), \$2 }' > $ENV_FILE"
run "chmod 600 $ENV_FILE && chown ubuntu:ubuntu $ENV_FILE"

# 3. nginx conf envsubst → /etc/nginx/conf.d
run "mkdir -p /etc/nginx/conf.d"
run "set -a && source $ENV_FILE && set +a && envsubst '\${DOMAIN_NAME}' < $APP_DIR/nginx/prod/wepick.conf > /etc/nginx/conf.d/wepick.conf"

# 4. ECR login
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
run "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

# 5. compose pull + up
cd "$APP_DIR/docker/prod"
if [[ "$SERVICE" == "all" ]]; then
  run "docker compose --env-file $ENV_FILE pull"
  run "docker compose --env-file $ENV_FILE up -d"
else
  run "docker compose --env-file $ENV_FILE pull $SERVICE"
  run "docker compose --env-file $ENV_FILE up -d $SERVICE"
fi

# 6. 이미지 정리
run "docker image prune -f"

# 7. health check — service에 맞춰 컨테이너 status 확인
if [[ "$SERVICE" == "all" ]]; then
  CONTAINERS="wepick_mysql wepick_backend wepick_frontend wepick_nginx"
else
  CONTAINERS="wepick_$SERVICE"
fi

echo "=== [deploy-on-ec2] health check (containers: $CONTAINERS) ==="
for C in $CONTAINERS; do
  STATUS=missing
  for i in $(seq 1 30); do
    STATUS=$(docker inspect --format '{{.State.Status}}' "$C" 2>/dev/null || echo missing)
    if [[ "$STATUS" == "running" ]]; then
      echo "$C: running (attempt $i)"
      break
    fi
    sleep 2
  done
  if [[ "$STATUS" != "running" ]]; then
    echo "ERROR: $C not running (status=$STATUS)" >&2
    exit 1
  fi
done

# service=all 일 때만 nginx 외부 접근 검증
if [[ "$SERVICE" == "all" ]]; then
  for i in $(seq 1 10); do
    if curl -fsS -o /dev/null http://localhost/; then
      echo "external http://localhost OK (attempt $i)"
      exit 0
    fi
    echo "external check pending (attempt $i)..."
    sleep 3
  done
  echo "ERROR: external health check failed after 10 attempts" >&2
  exit 1
fi
