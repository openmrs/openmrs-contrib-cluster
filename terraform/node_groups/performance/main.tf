provider "aws" {
  region = "ap-south-1"
}

terraform {
  required_version = "~>1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.32.0"
    }
  }

  backend "s3" {
    key = "nodegroup/performance/terraform.tfstate"
  }
}

module "node_group" {
  source               = "../../modules/eks_node_group"
  cluster_name         = var.cluster_name
  node_group_name      = var.node_group_name
  desired_num_of_nodes = var.desired_num_of_nodes
  max_num_of_nodes     = var.max_num_of_nodes
  min_num_of_nodes     = var.min_num_of_nodes
  node_instance_type   = var.node_instance_type
  node_role_name       = var.node_role_name
}
