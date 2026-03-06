# GrowTechStack Infrastructure

전체 서비스 운영을 위한 공통 인프라 설정 및 관리 도구입니다.

## 구성 요소

- **Database**: MariaDB 10.11 (MySQL 호환)
- **Messaging**: Apache Kafka 3.8
- **Network**: Docker Bridge Network (`gts-network`)

## 주요 파일

- `docker-compose.yml`: 로컬 개발 환경 전체 컨테이너 구성
- `ec2/`: AWS EC2 배포 스크립트 및 설정
- `kafka/`: Kafka 설정 및 클러스터 관리

## 인프라 시작 (Docker Compose)

```bash
docker-compose up -d
```

## 주요 접속 정보

| 서비스 | 주소 |
|------|------|
| MySQL | `localhost:3306` |
| Kafka | `localhost:9093` |
| Eureka | `localhost:8761` |
| Gateway | `localhost:8080` |
