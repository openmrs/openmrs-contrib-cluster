resource "aws_security_group" "bastion" {
  name        = "openmrs-bastion-sg-${var.vpc_suffix}"
  description = "SG for OpenMRS Bastion Host"
  vpc_id      = data.aws_vpc.openmrs-vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_access_cidr_block]
    description = "Rule to allow SSH Access"
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "Rule to allow EC2 to connect to Internet"
  }
  tags = {
    Name = "openmrs-bastion-sg-${var.vpc_suffix}"
  }
}