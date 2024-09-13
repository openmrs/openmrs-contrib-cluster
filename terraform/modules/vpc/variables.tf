variable "availability_zones" {
  type        = list(string)
  description = "Availability Zone for creating the resource"
}

variable "owner" {
  type        = string
  description = "Owner name for resource tags"
}

variable "vpc_suffix" {
  type        = string
  description = "Suffix Value for VPC related resources (Ex: prod,nonprod)"
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