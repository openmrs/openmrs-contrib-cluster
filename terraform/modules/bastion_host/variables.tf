variable "vpc_suffix" {
  type        = string
  description = "Suffix Value for VPC related resources (Ex: prod,nonprod)"
}

variable "public_access_cidr_block" {
  type        = string
  description = "CIDR Block used for SSH Access"
}