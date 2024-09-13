
resource "aws_security_group" "rds" {
  name        = "openmrs-rds-sg-${var.environment}"
  description = "RDS Security Group"
  vpc_id      = data.aws_vpc.openmrs-vpc.id

  ingress {
    from_port   = var.mysql_rds_port
    to_port     = var.mysql_rds_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.openmrs-vpc.cidr_block]
    description = "Allows Input connection on MySQL Port"
  }
  tags = {
    Name = "openmrs-rds-sg-${var.environment}"
  }
}
