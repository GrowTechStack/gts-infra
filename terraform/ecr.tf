resource "aws_ecr_repository" "collector" {
  name                 = "gts-collector-service"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "gts-collector-service" }
}

resource "aws_ecr_repository" "ai_summary" {
  name                 = "gts-ai-summary-service"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "gts-ai-summary-service" }
}

resource "aws_ecr_repository" "eureka" {
  name                 = "gts-eureka-server"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "gts-eureka-server" }
}

resource "aws_ecr_repository" "gateway" {
  name                 = "gts-gateway"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "gts-gateway" }
}

resource "aws_ecr_repository" "auth" {
  name                 = "gts-auth-service"
  image_tag_mutability = "MUTABLE"
  tags                 = { Name = "gts-auth-service" }
}
