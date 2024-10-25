locals {
  region = "us-east-2"
}

provider "aws" {
  region = local.region
}

terraform {
  required_version = ">= 1.4.5, < 1.5"

  required_providers {
    aws = ">= 5.0.1, < 5.1"
    tls = "4.0.6"
  }

  backend "s3" {
    bucket         = "openmrs-terraform-global"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "openmrs-terraform-global-locks"
    encrypt        = true
  }
}

module "vpc" {
  source              = "./modules/vpc"
  vpc_suffix          = var.vpc_suffix
  availability_zones  = var.availability_zones
  owner               = var.owner
  private_cidr_blocks = var.private_cidr_blocks
  public_cidr_blocks  = var.public_cidr_blocks
  vpc_cidr_block      = var.vpc_cidr_block
}

module "eks" {
  source               = "./modules/eks"
  depends_on           = [module.vpc]
  environment          = var.environment
  owner                = var.owner
  vpc_suffix           = var.vpc_suffix
  eks_version          = var.eks_version
  node_instance_type   = var.eks_node_instance_type
  desired_num_of_nodes = var.eks_desired_num_of_nodes
  min_num_of_nodes     = var.eks_min_num_of_nodes
  max_num_of_nodes     = var.eks_max_num_of_nodes
}

module "rds" {
  source                          = "./modules/rds"
  count                           = var.enable_rds ? 1 : 0
  depends_on                      = [module.vpc]
  environment                     = var.environment
  vpc_suffix                      = var.vpc_suffix
  mysql_rds_port                  = var.mysql_rds_port
  mysql_version                   = var.mysql_version
  rds_instance_class              = var.rds_instance_class
  rds_allow_major_version_upgrade = var.rds_allow_major_version_upgrade
  mysql_time_zone                 = var.mysql_time_zone
}

module "ses" {
  source      = "./modules/ses"
  count       = var.enable_ses ? 1 : 0
  depends_on  = [module.vpc]
  domain_name = var.domain_name
  zone_id     = var.hosted_zone_id
}

module "bastion" {
  source                   = "./modules/bastion_host"
  count                    = var.enable_bastion_host ? 1 : 0
  depends_on               = [module.vpc]
  vpc_suffix               = var.vpc_suffix
  public_access_cidr_block = var.bastion_public_access_cidr
}
