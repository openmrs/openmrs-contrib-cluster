resource "aws_security_group" "bahmni-efs-sg" {
  name        = "bahmni-efs-sg-${var.environment}"
  description = "SG for Bahmni EFS"
  vpc_id      = data.aws_vpc.bahmni-vpc.id
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.private_cidr_blocks
    description = "Rule to allow inbound NFS traffic"
  }
  tags = {
    Name = "bahmni-efs-sg-${var.environment}"
  }
}
