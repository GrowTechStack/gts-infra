resource "aws_db_subnet_group" "gts" {
  name       = "gts-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  tags       = { Name = "gts-db-subnet-group" }
}

resource "aws_db_instance" "gts" {
  identifier              = "gts-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  db_name                 = "growtechstack"
  username                = "gts"
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.gts.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  backup_retention_period = 0
  multi_az                = false
  publicly_accessible     = false
  tags                    = { Name = "gts-mysql" }
}
