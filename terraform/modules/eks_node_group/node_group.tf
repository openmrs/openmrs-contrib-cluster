resource "aws_eks_node_group" "node_group" {
  node_group_name = var.node_group_name
  cluster_name    = data.aws_eks_cluster.eks_cluster.name
  node_role_arn   = data.aws_iam_role.node_role.arn
  subnet_ids      = data.aws_eks_cluster.eks_cluster.vpc_config[0].subnet_ids
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"
  version         = data.aws_eks_cluster.eks_cluster.version

  scaling_config {
    desired_size = var.desired_num_of_nodes
    max_size     = var.max_num_of_nodes
    min_size     = var.min_num_of_nodes
  }
}
