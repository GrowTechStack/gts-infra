#!/bin/bash
set -e
SERVICE=$1
REGION=ap-northeast-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

case "$SERVICE" in
  collector)
    docker compose -f /app/docker-compose.prod.yml pull gts-collector-service
    docker compose -f /app/docker-compose.prod.yml up -d gts-collector-service
    ;;
  ai-summary)
    docker compose -f /app/docker-compose.prod.yml pull gts-ai-summary-service
    docker compose -f /app/docker-compose.prod.yml up -d gts-ai-summary-service
    ;;
  gateway)
    docker compose -f /app/docker-compose.prod.yml pull gts-gateway
    docker compose -f /app/docker-compose.prod.yml up -d gts-gateway
    ;;
  eureka)
    docker compose -f /app/docker-compose.prod.yml pull gts-eureka-server
    docker compose -f /app/docker-compose.prod.yml up -d gts-eureka-server
    ;;
  *)
    echo "Usage: deploy.sh [collector|ai-summary|gateway|eureka]"
    exit 1
    ;;
esac
