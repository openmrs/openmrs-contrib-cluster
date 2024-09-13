output "cluster-name" {
  value = aws_eks_cluster.openmrs-cluster.name
}

output "endpoint" {
  value = aws_eks_cluster.openmrs-cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.openmrs-cluster.certificate_authority[0].data
}
