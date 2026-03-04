#!/bin/bash
set -e

# Setup swap (1GB) - t2.micro RAM 부족 방지
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Install Docker
dnf update -y
dnf install -y docker cronie
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# ECR Login
aws ecr get-login-password --region ${aws_region} | \
  docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${aws_region}.amazonaws.com

# ECR 토큰 자동 갱신 (12시간마다 만료되므로 6시간마다 갱신)
systemctl enable crond
systemctl start crond
mkdir -p /etc/cron.d
cat > /etc/cron.d/ecr-refresh << 'CRONEOF'
0 */6 * * * root aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${account_id}.dkr.ecr.${aws_region}.amazonaws.com >> /var/log/ecr-refresh.log 2>&1
CRONEOF

# Create app directory
mkdir -p /app

# Write docker-compose.prod.yml
cat > /app/docker-compose.prod.yml << 'COMPOSEEOF'
services:
  gts-ai-summary-service:
    image: ${account_id}.dkr.ecr.${aws_region}.amazonaws.com/gts-ai-summary-service:latest
    container_name: gts-ai-summary
    ports:
      - "29998:29998"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      AI_API_KEY: "${ai_api_key}"
      KAFKA_BOOTSTRAP_SERVERS: "${kafka_bootstrap_servers}"
      SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL: SASL_SSL
      SPRING_KAFKA_PROPERTIES_SASL_MECHANISM: PLAIN
      SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG: "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${kafka_api_key}\" password=\"${kafka_api_secret}\";"
    restart: on-failure

  gts-collector-service:
    image: ${account_id}.dkr.ecr.${aws_region}.amazonaws.com/gts-collector-service:latest
    container_name: gts-collector-service
    ports:
      - "29999:29999"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      DB_HOST: "${db_host}"
      DB_NAME: growtechstack
      DB_USERNAME: gts
      DB_PASSWORD: "${db_password}"
      KAFKA_BOOTSTRAP_SERVERS: "${kafka_bootstrap_servers}"
      SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL: SASL_SSL
      SPRING_KAFKA_PROPERTIES_SASL_MECHANISM: PLAIN
      SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG: "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${kafka_api_key}\" password=\"${kafka_api_secret}\";"
    restart: on-failure
COMPOSEEOF

# Write deploy script (GitHub Actions에서 호출)
cat > /app/deploy.sh << 'DEPLOYEOF'
#!/bin/bash
set -e

SERVICE=$1  # collector 또는 ai-summary

aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-northeast-2.amazonaws.com

if [ "$SERVICE" = "collector" ]; then
  docker compose -f /app/docker-compose.prod.yml pull gts-collector-service
  docker compose -f /app/docker-compose.prod.yml up -d gts-collector-service
elif [ "$SERVICE" = "ai-summary" ]; then
  docker compose -f /app/docker-compose.prod.yml pull gts-ai-summary-service
  docker compose -f /app/docker-compose.prod.yml up -d gts-ai-summary-service
else
  docker compose -f /app/docker-compose.prod.yml pull
  docker compose -f /app/docker-compose.prod.yml up -d
fi
DEPLOYEOF
chmod +x /app/deploy.sh

# 이미지가 ECR에 없으면 실패 → 이미지 푸시 후 수동으로 docker compose up -d 실행
docker compose -f /app/docker-compose.prod.yml pull && \
  docker compose -f /app/docker-compose.prod.yml up -d || \
  echo "[GTS] ECR에 이미지를 먼저 푸시한 후 'docker compose -f /app/docker-compose.prod.yml up -d' 실행하세요."
