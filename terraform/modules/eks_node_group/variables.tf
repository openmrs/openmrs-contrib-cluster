variable "node_group_name" {
  type        = string
  description = "Name of the node group"
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

variable "node_instance_type" {
  type        = string
  description = "Type of Instance to be used for nodes"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster to associate the node group"
}

variable "node_role_name" {
  type        = string
  description = "Name of the IAM Role to add to nodes in node group"
}
