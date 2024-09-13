resource "aws_db_parameter_group" "custom_mysql_parameters" {
  name   = "mysql-custom-parameter-group-${var.environment}"
  family = "mysql5.7"

  parameter {
    name         = "log_bin_trust_function_creators"
    value        = 1
    apply_method = "immediate"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "collation_server"
    value = "utf8_general_ci"
  }

  parameter {
    name  = "time_zone"
    value = var.mysql_time_zone
  }
}

resource "aws_db_parameter_group" "custom_mysql8_0_parameters" {
  name   = "mysql8-0-custom-parameter-group-${var.environment}"
  family = "mysql8.0"

  parameter {
    name         = "log_bin_trust_function_creators"
    value        = 1
    apply_method = "immediate"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_0900_ai_ci"
  }

  parameter {
    name  = "time_zone"
    value = var.mysql_time_zone
  }
}