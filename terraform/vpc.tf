resource "aws_vpc" "gts" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "gts-vpc" }
}

resource "aws_internet_gateway" "gts" {
  vpc_id = aws_vpc.gts.id
  tags   = { Name = "gts-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.gts.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "gts-public-subnet" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.gts.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "gts-private-subnet-a" }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.gts.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}c"
  tags              = { Name = "gts-private-subnet-c" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.gts.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gts.id
  }

  tags = { Name = "gts-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
