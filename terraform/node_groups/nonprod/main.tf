provider "aws" {
  region = "us-east-2"
}

terraform {
  required_version = ">= 1.4.5, < 1.5"

  required_providers {
    aws = ">= 5.0.1, < 5.1"
  }

  backend "s3" {
    bucket         = "openmrs-terraform-global"
    key            = "nodegroup/nonprod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "openmrs-terraform-global-locks"
    encrypt        = true
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
