#!/bin/bash
set -e

# Setup swap (1GB) - t3.micro RAM 부족 방지
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Install Docker
dnf update -y
dnf install -y docker cronie nginx nano
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

# ECR 토큰 자동 갱신 (6시간마다)
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
  gts-eureka-server:
    image: ${account_id}.dkr.ecr.${aws_region}.amazonaws.com/gts-eureka-server:latest
    container_name: gts-eureka-server
    ports:
      - "8761:8761"
    environment:
      SPRING_PROFILES_ACTIVE: docker
    restart: on-failure
    networks:
      - gts-network

  gts-gateway:
    image: ${account_id}.dkr.ecr.${aws_region}.amazonaws.com/gts-gateway:latest
    container_name: gts-gateway
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      EUREKA_URL: http://gts-eureka-server:8761/eureka/
      JWT_SECRET: "${jwt_secret}"
    depends_on:
      - gts-eureka-server
    restart: on-failure
    networks:
      - gts-network

  gts-auth-service:
    image: ${account_id}.dkr.ecr.${aws_region}.amazonaws.com/gts-auth-service:latest
    container_name: gts-auth-service
    ports:
      - "29997:29997"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      EUREKA_URL: http://gts-eureka-server:8761/eureka/
      DB_HOST: "${db_host}"
      DB_NAME: growtechstack
      DB_USERNAME: gts
      DB_PASSWORD: "${db_password}"
      JWT_SECRET: "${jwt_secret}"
    depends_on:
      - gts-eureka-server
    restart: on-failure
    networks:
      - gts-network

  gts-ai-summary-service:
    image: ${account_id}.dkr.ecr.${aws_region}.amazonaws.com/gts-ai-summary-service:latest
    container_name: gts-ai-summary-service
    ports:
      - "29998:29998"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      AI_API_KEY: "${ai_api_key}"
      KAFKA_BOOTSTRAP_SERVERS: "${kafka_bootstrap_servers}"
      SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL: SASL_SSL
      SPRING_KAFKA_PROPERTIES_SASL_MECHANISM: PLAIN
      SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG: "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${kafka_api_key}\" password=\"${kafka_api_secret}\";"
      EUREKA_URL: http://gts-eureka-server:8761/eureka/
    depends_on:
      - gts-eureka-server
    restart: on-failure
    networks:
      - gts-network

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
      EUREKA_URL: http://gts-eureka-server:8761/eureka/
    depends_on:
      - gts-eureka-server
    restart: on-failure
    networks:
      - gts-network

networks:
  gts-network:
    driver: bridge
COMPOSEEOF

# Write Nginx config
mkdir -p /etc/nginx/conf.d
cat > /etc/nginx/conf.d/growtechstack.conf << 'NGINXEOF'
server {
    listen 80;
    server_name growtechstack.com www.growtechstack.com;
    return 301 https://$host$request_uri;
    }

    server {
    listen 443 ssl;
    server_name growtechstack.com www.growtechstack.com;

    ssl_certificate     /etc/letsencrypt/live/growtechstack.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/growtechstack.com/privkey.pem;

    # Frontend → Vercel
    location / {
        proxy_pass         https://gts-frontend.vercel.app;
        proxy_ssl_server_name on;
        proxy_set_header   Host gts-frontend.vercel.app;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # API → Gateway
    location /api/ {
        proxy_pass         http://localhost:8080/api/;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    # Swagger (collector → gateway 경유)
    location /swagger-ui/ {
        proxy_pass         http://localhost:29999/swagger-ui/;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
    }
    location /v3/api-docs {
        proxy_pass         http://localhost:29999/v3/api-docs;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
    }
NGINXEOF

systemctl enable nginx
systemctl start nginx || true  # SSL 인증서 없으면 첫 부팅 시 실패 — certbot 설정 후 재시작

# Write deploy script (GitHub Actions에서 호출)
cat > /app/deploy.sh << 'DEPLOYEOF'
#!/bin/bash
set -e

SERVICE=$1
REGION=ap-northeast-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$${ACCOUNT_ID}.dkr.ecr.$${REGION}.amazonaws.com"

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
  auth)
    docker compose -f /app/docker-compose.prod.yml pull gts-auth-service
    docker compose -f /app/docker-compose.prod.yml up -d gts-auth-service
    ;;
  *)
    docker compose -f /app/docker-compose.prod.yml pull
    docker compose -f /app/docker-compose.prod.yml up -d
    ;;
esac
DEPLOYEOF
chmod +x /app/deploy.sh

# 이미지가 ECR에 없으면 실패 → 이미지 푸시 후 수동으로 docker compose up -d 실행
docker compose -f /app/docker-compose.prod.yml pull && \
  docker compose -f /app/docker-compose.prod.yml up -d || \
  echo "[GTS] ECR에 이미지를 먼저 푸시한 후 'docker compose -f /app/docker-compose.prod.yml up -d' 실행하세요."
