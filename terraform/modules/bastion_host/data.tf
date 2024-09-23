data "aws_ami" "amazon_linux_2" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.20220316.0-x86_64-gp2"]
  }
  owners = ["amazon"]
}

data "aws_vpc" "openmrs-vpc" {
  filter {
    name   = "tag:Name"
    values = ["openmrs-vpc-${var.vpc_suffix}"]
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