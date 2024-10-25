variable "environment" {
  type        = string
  description = "Environment Value used to create and tag resources"
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

variable "node_instance_type" {
  type        = string
  description = "Type of Instance to be used for nodes"
}

variable "desired_num_of_nodes" {
  type        = number
  description = "Number of desired nodes in the default node group"
}

variable "min_num_of_nodes" {
  type        = number
  description = "Number of minimum nodes in the default node group"
}

variable "max_num_of_nodes" {
  type        = number
  description = "Number of maximum nodes in the default node group"
}