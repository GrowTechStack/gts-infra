data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_key_pair" "gts" {
  key_name   = "gts-key"
  public_key = var.public_key
}

resource "aws_iam_role" "ec2" {
  name = "gts-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "gts-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "gts" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = aws_key_pair.gts.key_name

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region              = var.aws_region
    account_id              = data.aws_caller_identity.current.account_id
    ai_api_key              = var.ai_api_key
    kafka_bootstrap_servers = var.kafka_bootstrap_servers
    kafka_api_key           = var.kafka_api_key
    kafka_api_secret        = var.kafka_api_secret
    db_host                 = aws_db_instance.gts.address
    db_password             = var.db_password
    jwt_secret              = var.jwt_secret
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "gts-ec2" }
}

resource "aws_eip" "gts" {
  instance = aws_instance.gts.id
  domain   = "vpc"

  tags = { Name = "gts-eip" }
}
