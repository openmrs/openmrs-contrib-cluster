variable "environment" {
  type        = string
  description = "Environment Value used to create and tag resources"
}

variable "vpc_suffix" {
  type        = string
  description = "Suffix Value for VPC related resources (Ex: prod,nonprod)"
}

variable "private_cidr_blocks" {
  type        = list(string)
  description = "CIDR Blocks used for private subnets"
}

