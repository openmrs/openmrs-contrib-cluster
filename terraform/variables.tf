variable "availability_zones" {
  type        = list(string)
  description = "Availability Zone for creating the resource"
}

variable "environment" {
  type        = string
  description = "Name of the environment with which resource names would be suffixed"
}

variable "owner" {
  type        = string
  description = "Owner name for resource tags"
}

variable "private_cidr_blocks" {
  type        = list(string)
  description = "CIDR Blocks used for private subnets"
}

variable "public_cidr_blocks" {
  type        = list(string)
  description = "CIDR Blocks used for public subnets"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR Block used for VPC"
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

variable "mysql_rds_port" {
  type        = string
  description = "RDS Port for MySQL Instance"
}

variable "mysql_time_zone" {
  type        = string
  description = "Time Zone for RDS Instance"
}

variable "enable_bastion_host" {
  type        = bool
  description = "Toggle for Bastion Host"
}

variable "bastion_public_access_cidr" {
  type        = string
  description = "CIDR Block used for SSH Access of Bastion Host"
}

variable "domain_name" {
  type        = string
  description = "Domain Name for Amazon SES service"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route 53 Hosted Zone ID for the domain_name"
}

variable "enable_ses" {
  type        = bool
  default     = false
  description = "Toggle for SES Module"
}

variable "rds_allow_major_version_upgrade" {
  type        = bool
  description = "Allow Major Version Upgrade for RDS Instance"

}

variable "eks_version" {
  type        = string
  description = "EKS Cluster Version"
}
