resource "aws_security_group" "cluster" {
  name        = "openmrs-cluster-sg-${var.environment}"
  description = "Cluster communication with worker nodes"
  vpc_id      = data.aws_vpc.openmrs-vpc.id

  tags = {
    Name  = "openmrs-cluster-sg-${var.environment}"
    owner = var.owner
  }
}

resource "aws_security_group" "node" {
  name        = "openmrs-node-sg-${var.environment}"
  description = "Security group for all nodes in the EKS cluster"
  vpc_id      = data.aws_vpc.openmrs-vpc.id

  tags = {
    Name  = "openmrs-node-sg-${var.environment}"
    owner = var.owner
  }
}
