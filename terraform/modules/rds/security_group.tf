
resource "aws_security_group" "rds" {
  name        = "bahmni-rds-sg-${var.environment}"
  description = "RDS Security Group"
  vpc_id      = data.aws_vpc.bahmni-vpc.id

  ingress {
    from_port   = var.mysql_rds_port
    to_port     = var.mysql_rds_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.bahmni-vpc.cidr_block]
    description = "Allows Input connection on MySQL Port"
  }
  tags = {
    Name = "bahmni-rds-sg-${var.environment}"
  }
}
