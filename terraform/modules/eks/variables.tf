variable "environment" {
  type        = string
  description = "Environment Value used to create and tag resources"
}

variable "efs_file_system_arn" {
  type        = string
  description = "EFS File System ARN"
  sensitive   = true
}

variable "owner" {
  type        = string
  description = "Owner name used for tagging resources"
}

variable "vpc_suffix" {
  type        = string
  description = "Suffix Value for VPC related resources (Ex: prod,nonprod)"
}

variable "eks_version" {
  type        = string
  description = "EKS Cluster Version"
}
