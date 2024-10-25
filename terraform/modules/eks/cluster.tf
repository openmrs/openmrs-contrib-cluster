resource "aws_eks_cluster" "openmrs-cluster" {
  name                      = "openmrs-cluster-${var.environment}"
  role_arn                  = aws_iam_role.cluster-role.arn
  enabled_cluster_log_types = ["api", "authenticator", "audit", "scheduler", "controllerManager"]
  vpc_config {
    subnet_ids              = data.aws_subnets.private_subnets.ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_EKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_EKSServicePolicy,
  ]

  tags = {
    owner = var.owner
  }

  version = var.eks_version
}

resource "aws_eks_node_group" "openmrs-node_group" {
  node_group_name = "openmrs-node-group-${var.environment}"
  cluster_name    = aws_eks_cluster.openmrs-cluster.name
  node_role_arn   = aws_iam_role.node-role.arn
  subnet_ids      = aws_eks_cluster.openmrs-cluster.vpc_config[0].subnet_ids
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"
  version         = aws_eks_cluster.openmrs-cluster.version

  scaling_config {
    desired_size = var.desired_num_of_nodes
    max_size     = var.max_num_of_nodes
    min_size     = var.min_num_of_nodes
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEBSCSIDriverPolicy
  ]
}

data "aws_eks_addon_version" "openmrs-ebs-addon-version" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.openmrs-cluster.version
  most_recent        = true
}

resource "aws_eks_addon" "openmrs-ebs-addon" {

  cluster_name = aws_eks_cluster.openmrs-cluster.name
  addon_name   = "aws-ebs-csi-driver"

  addon_version               = data.aws_eks_addon_version.openmrs-ebs-addon-version.version
  configuration_values        = null
  preserve                    = true
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
}


