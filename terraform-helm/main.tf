locals {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket         = "openmrs-terraform-helm"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "openmrs-terraform-helm-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = local.region
}

data "aws_eks_cluster" "default" {
  name = "openmrs-cluster-${var.environment}"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.default.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
      command     = "aws"
    }
  }
}

data "aws_iam_openid_connect_provider" "default" {
  url = data.aws_eks_cluster.default.identity[0].oidc[0].issuer
}

module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = data.aws_iam_openid_connect_provider.default.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.11"

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "vpcId"
    value = data.aws_eks_cluster.default.vpc_config[0].vpc_id
  }

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.default.id
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

resource "helm_release" "openmrs" {
  name = "openmrs"

  repository = "oci://registry-1.docker.io/openmrs"
  chart      = "openmrs"
  version    = "0.1.4"

  set {
    name  = "openmrs-gateway.ingress.enabled"
    value = "true"
  }

  set {
    name  = "openmrs-gateway.ingress.className"
    value = "alb"
  }
}
