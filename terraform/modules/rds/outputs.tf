output "rds_user_name" {
  value = random_string.mysql_user_name.result
}

output "rds_password" {
  value = random_string.mysql_user_password.result
}

output "rds_host" {
  value = aws_db_instance.mysql.address
}