data "aws_vpc" "openmrs-vpc" {
  filter {
    name   = "tag:Name"
    values = ["openmrs-vpc-${var.vpc_suffix}"]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.openmrs-vpc.id]
  }
  filter {
    name   = "tag:Subnet-Type"
    values = ["private-${var.vpc_suffix}"]
  }
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.openmrs-vpc.id]
  }
  filter {
    name   = "tag:Subnet-Type"
    values = ["public-${var.vpc_suffix}"]
  }
}
