variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "public_key" {
  description = "SSH public key (run: ssh-keygen -t rsa -b 4096 -f ~/.ssh/gts-key)"
  type        = string
}

variable "db_password" {
  description = "RDS MySQL password"
  type        = string
  sensitive   = true
}

variable "ai_api_key" {
  description = "Groq API Key"
  type        = string
  sensitive   = true
}

variable "kafka_bootstrap_servers" {
  description = "Confluent Cloud Kafka bootstrap servers (e.g. pkc-xxx.ap-southeast-1.aws.confluent.cloud:9092)"
  type        = string
}

variable "kafka_api_key" {
  description = "Confluent Cloud Kafka API Key"
  type        = string
  sensitive   = true
}

variable "kafka_api_secret" {
  description = "Confluent Cloud Kafka API Secret"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret (32+ chars, shared between gateway and auth-service)"
  type        = string
  sensitive   = true
}
