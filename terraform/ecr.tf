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
