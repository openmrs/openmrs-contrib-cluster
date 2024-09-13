resource "aws_security_group" "cluster" {
  name        = "bahmni-cluster-sg-${var.environment}"
  description = "Cluster communication with worker nodes"
  vpc_id      = data.aws_vpc.bahmni-vpc.id

  tags = {
    Name  = "bahmni-cluster-sg-${var.environment}"
    owner = var.owner
  }
}

resource "aws_security_group" "node" {
  name        = "bahmni-node-sg-${var.environment}"
  description = "Security group for all nodes in the EKS cluster"
  vpc_id      = data.aws_vpc.bahmni-vpc.id

  tags = {
    Name  = "bahmni-node-sg-${var.environment}"
    owner = var.owner
  }
}
