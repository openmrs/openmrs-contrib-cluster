resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.openmrs-vpc.id
  availability_zone       = var.availability_zones[0]
  cidr_block              = var.public_cidr_blocks[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "openmrs-public-subnet-a-${var.vpc_suffix}"
    owner                    = var.owner
    Subnet-Type              = "public-${var.vpc_suffix}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.openmrs-vpc.id
  availability_zone       = var.availability_zones[1]
  cidr_block              = var.public_cidr_blocks[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "openmrs-public-subnet-b-${var.vpc_suffix}"
    owner                    = var.owner
    Subnet-Type              = "public-${var.vpc_suffix}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.openmrs-vpc.id
  availability_zone       = var.availability_zones[0]
  cidr_block              = var.private_cidr_blocks[0]
  map_public_ip_on_launch = false

  tags = {
    Name                              = "openmrs-private-subnet-a-${var.vpc_suffix}"
    owner                             = var.owner
    Subnet-Type                       = "private-${var.vpc_suffix}"
    "kubernetes.io/role/internal-elb" = "1"
  }

}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.openmrs-vpc.id
  availability_zone       = var.availability_zones[1]
  cidr_block              = var.private_cidr_blocks[1]
  map_public_ip_on_launch = false

  tags = {
    Name                              = "openmrs-private-subnet-b-${var.vpc_suffix}"
    owner                             = var.owner
    Subnet-Type                       = "private-${var.vpc_suffix}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

