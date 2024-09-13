resource "aws_db_subnet_group" "mysql-subnet" {
  name       = "mysql-subnet-group-${var.environment}"
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = {
    Name = "Bahmni MySQL DB Subnet for ${var.environment}"
  }
}

resource "aws_db_instance" "mysql" {
  identifier                  = "bahmni-rds-${var.environment}"
  allocated_storage           = 10
  max_allocated_storage       = 30
  skip_final_snapshot         = true
  engine                      = "mysql"
  engine_version              = var.mysql_version
  instance_class              = var.rds_instance_class
  username                    = random_string.mysql_user_name.result
  password                    = random_string.mysql_user_password.result
  vpc_security_group_ids      = [aws_security_group.rds.id]
  storage_encrypted           = true
  db_subnet_group_name        = aws_db_subnet_group.mysql-subnet.name
  publicly_accessible         = false
  apply_immediately           = true
  allow_major_version_upgrade = var.rds_allow_major_version_upgrade
  port                        = var.mysql_rds_port
  backup_retention_period     = 2
  parameter_group_name        = aws_db_parameter_group.custom_mysql8_0_parameters.name
}

resource "random_string" "mysql_user_name" {
  length  = 8
  upper   = false
  special = false
  numeric = false
}

resource "random_string" "mysql_user_password" {
  length           = 16
  special          = true
  override_special = "#%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "rds_mysql_username" {
  name        = "/${var.environment}/rds/mysql/username"
  description = "MySQL RDS Master Username for ${var.environment}"
  type        = "SecureString"
  value       = aws_db_instance.mysql.username
}

resource "aws_ssm_parameter" "rds_mysql_password" {
  name        = "/${var.environment}/rds/mysql/password"
  description = "MySQL RDS Master Password for ${var.environment}"
  type        = "SecureString"
  value       = aws_db_instance.mysql.password
}

resource "aws_ssm_parameter" "rds_mysql_host" {
  name        = "/${var.environment}/rds/mysql/host"
  description = "MySQL RDS Host for ${var.environment}"
  type        = "SecureString"
  value       = aws_db_instance.mysql.address
}
