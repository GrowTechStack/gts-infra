# GrowTechStack Infrastructure

GrowTechStack 서비스 운영을 위한 인프라 구성 및 배포 설정입니다.

## 구성 요소

| 경로 | 설명 |
|------|------|
| `terraform/` | AWS 인프라 정의 (VPC, EC2, RDS, ECR, Security Group) |
| `ec2/deploy.sh` | 서비스별 ECR pull + 컨테이너 재시작 스크립트 |
| `ec2/docker-compose.prod.yml` | 운영 컨테이너 구성 (`.gitignore` 처리됨) |
| `ec2/nginx/growtechstack.conf` | Nginx 리버스 프록시 설정 |
| `docker-compose.yml` | 로컬 개발용 컨테이너 구성 (MySQL + Kafka) |

## AWS 인프라 (Terraform)

| 리소스 | 설명 |
|--------|------|
| VPC | 전용 가상 네트워크 (ap-northeast-2) |
| EC2 | 컨테이너 실행 서버 (Amazon Linux 2) |
| RDS | MySQL 8.0 데이터베이스 |
| ECR | Docker 이미지 레지스트리 (서비스별 4개) |
| Security Group | 포트 접근 제어 |

## ECR 레포지토리

| 레포지토리 | 서비스 |
|------------|--------|
| `gts-collector-service` | RSS 수집 서비스 |
| `gts-ai-summary-service` | AI 요약 서비스 |
| `gts-gateway` | API 게이트웨이 |
| `gts-eureka-server` | 서비스 디스커버리 |

## 운영 서버 포트 구성

| 포트 | 서비스 |
|------|--------|
| 80 / 443 | Nginx (HTTPS, Let's Encrypt) |
| 8080 | API Gateway |
| 8761 | Eureka Dashboard |
| 29999 | Collector Service |
| 29998 | AI Summary Service |

## 배포 흐름

```
GitHub Actions (각 서비스 레포)
    └── Docker build & push → ECR
    └── SSH → EC2 /app/deploy.sh {service}
              └── docker compose pull & up -d
```

## 로컬 개발 환경

`docker-compose.yml`로 MySQL + Kafka를 로컬에서 실행합니다.
각 서비스는 `application-dev.yml` 프로파일로 로컬 컨테이너에 연결됩니다.
