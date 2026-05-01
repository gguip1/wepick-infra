#!/usr/bin/env bash
# SSM SendCommand가 EC2에서 실행하는 배포 스크립트.
# 사용법: deploy-on-ec2.sh <service>
#   service: backend | frontend | nginx | mysql | all
# 환경변수:
#   DRY_RUN=1 — 실제 명령은 실행하지 않고 출력만
set -eu
set -o pipefail 2>/dev/null || true   # dash에서 무시

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
get_param() {
  aws ssm get-parameter \
    --name "/${PROJECT_NAME}/$1" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text \
    --region "$AWS_REGION"
}

write_required_env() {
  key="$1"
  param="$2"
  value=$(get_param "$param")
  printf "%s=%s\n" "$key" "$value" >> "$ENV_FILE"
}

write_optional_env() {
  key="$1"
  param="$2"
  default="$3"
  if value=$(get_param "$param" 2>/dev/null); then
    printf "%s=%s\n" "$key" "$value" >> "$ENV_FILE"
  else
    printf "%s=%s\n" "$key" "$default" >> "$ENV_FILE"
  fi
}

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "DRY_RUN: create $ENV_FILE from explicit SSM parameter mapping"
else
  : > "$ENV_FILE"
  write_optional_env "AWS_REGION" "aws_region" "$AWS_REGION"
  write_required_env "MYSQL_ROOT_PASSWORD" "mysql_root_password"
  write_required_env "MYSQL_PASSWORD" "mysql_password"
  write_required_env "MYSQL_USER" "mysql_user"
  write_required_env "MYSQL_HOST" "mysql_host"
  write_required_env "MYSQL_PORT" "mysql_port"
  write_required_env "MYSQL_DATABASE" "mysql_database"
  write_required_env "BE_IMAGE" "be_image"
  write_required_env "BE_IMAGE_TAG" "be_image_tag"
  write_required_env "FE_IMAGE" "fe_image"
  write_required_env "FE_IMAGE_TAG" "fe_image_tag"
  write_required_env "DOMAIN_NAME" "domain_name"
  write_required_env "CORS_ALLOWED_ORIGINS" "cors_allowed_origins"
  write_required_env "SESSION_COOKIE_SAME_SITE" "session_cookie_same_site"
  write_required_env "CLOUD_AWS_S3_DOMAIN" "cloud_aws_s3_domain"
  write_required_env "S3_BUCKET_NAME" "s3_bucket_name"
  chmod 600 "$ENV_FILE"
  chown ubuntu:ubuntu "$ENV_FILE"
fi

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
