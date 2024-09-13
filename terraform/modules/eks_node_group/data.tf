data "aws_eks_cluster" "eks_cluster" {
  name = var.cluster_name
}

data "aws_iam_role" "node_role" {
  name = var.node_role_name
}
