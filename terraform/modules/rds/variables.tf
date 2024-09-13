variable "environment" {
  type        = string
  description = "Environment Value used to create and tag resources"
}

variable "mysql_rds_port" {
  type        = string
  description = "RDS Port for MySQL Instance"
}

variable "vpc_suffix" {
  type        = string
  description = "Suffix Value for VPC related resources (Ex: prod,nonprod)"
}

variable "mysql_version" {
  type        = string
  description = "MySQL Version for RDS instance"
}

variable "rds_instance_class" {
  type        = string
  description = "Instance class for RDS Instance"
}

variable "mysql_time_zone" {
  type        = string
  description = "Time Zone for RDS Instance"
}

variable "rds_allow_major_version_upgrade" {
  type        = bool
  description = "Allow Major Version Upgrade for RDS Instance"
}
