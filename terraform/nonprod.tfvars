environment                     = "nonprod"
vpc_suffix                      = "nonprod"
owner                           = "openmrs-infra"
availability_zones              = ["us-east-2a", "us-east-2b"]
private_cidr_blocks             = ["10.0.1.0/24", "10.0.2.0/24"]
public_cidr_blocks              = ["10.0.3.0/24", "10.0.4.0/24"]
vpc_cidr_block                  = "10.0.0.0/16"
enable_rds                      = true
rds_instance_class              = "db.t3.small"
rds_allow_major_version_upgrade = true
mysql_version                   = "8.0"
mysql_rds_port                  = "3306"
mysql_time_zone                 = "US/Eastern"
enable_bastion_host             = false
bastion_public_access_cidr      = "0.0.0.0/0"
enable_ses                      = false
eks_version                     = "1.31"
eks_node_instance_type          = "t3.medium"
eks_desired_num_of_nodes        = 3
eks_min_num_of_nodes            = 3
eks_max_num_of_nodes            = 6