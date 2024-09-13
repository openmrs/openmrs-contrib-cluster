resource "aws_vpc" "bahmni-vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name  = "bahmni-vpc-${var.vpc_suffix}"
    owner = var.owner
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.bahmni-vpc.id

  tags = {
    Name  = "bahmni-igw-${var.vpc_suffix}"
    owner = var.owner
  }
}

resource "aws_eip" "nat_eip_az_a" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name  = "bahmni-nat-eip-az-a-${var.vpc_suffix}"
    owner = var.owner
  }
}

resource "aws_eip" "nat_eip_az_b" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name  = "bahmni-nat-eip-az-b-${var.vpc_suffix}"
    owner = var.owner
  }
}

resource "aws_nat_gateway" "nat_az_a" {
  allocation_id = aws_eip.nat_eip_az_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name  = "bahmni-nat-gateway-az-a-${var.vpc_suffix}"
    owner = var.owner
  }
}

resource "aws_nat_gateway" "nat_az_b" {
  allocation_id = aws_eip.nat_eip_az_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = {
    Name  = "bahmni-nat-gateway-az-b-${var.vpc_suffix}"
    owner = var.owner
  }
}
