resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.bahmni-vpc.id
  availability_zone       = var.availability_zones[0]
  cidr_block              = var.public_cidr_blocks[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "bahmni-public-subnet-a-${var.vpc_suffix}"
    owner       = var.owner
    Subnet-Type = "public-${var.vpc_suffix}"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.bahmni-vpc.id
  availability_zone       = var.availability_zones[1]
  cidr_block              = var.public_cidr_blocks[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "bahmni-public-subnet-b-${var.vpc_suffix}"
    owner       = var.owner
    Subnet-Type = "public-${var.vpc_suffix}"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.bahmni-vpc.id
  availability_zone       = var.availability_zones[0]
  cidr_block              = var.private_cidr_blocks[0]
  map_public_ip_on_launch = false

  tags = {
    Name        = "bahmni-private-subnet-a-${var.vpc_suffix}"
    owner       = var.owner
    Subnet-Type = "private-${var.vpc_suffix}"
  }

}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.bahmni-vpc.id
  availability_zone       = var.availability_zones[1]
  cidr_block              = var.private_cidr_blocks[1]
  map_public_ip_on_launch = false

  tags = {
    Name        = "bahmni-private-subnet-b-${var.vpc_suffix}"
    owner       = var.owner
    Subnet-Type = "private-${var.vpc_suffix}"
  }
}

