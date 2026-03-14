output "ec2_public_ip" {
  description = "EC2 Elastic IP"
  value       = aws_eip.gts.public_ip
}

output "rds_endpoint" {
  description = "RDS Endpoint"
  value       = aws_db_instance.gts.address
}

output "ecr_collector_url" {
  description = "ECR URL for gts-collector-service"
  value       = aws_ecr_repository.collector.repository_url
}

output "ecr_ai_summary_url" {
  description = "ECR URL for gts-ai-summary-service"
  value       = aws_ecr_repository.ai_summary.repository_url
}
