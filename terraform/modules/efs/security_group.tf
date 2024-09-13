resource "aws_security_group" "openmrs-efs-sg" {
  name        = "openmrs-efs-sg-${var.environment}"
  description = "SG for OpenMRS EFS"
  vpc_id      = data.aws_vpc.openmrs-vpc.id
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.private_cidr_blocks
    description = "Rule to allow inbound NFS traffic"
  }
  tags = {
    Name = "openmrs-efs-sg-${var.environment}"
  }
}
