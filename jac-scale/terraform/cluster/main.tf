locals {
  # Used across all resources for consistent naming and discovery tagging
  tags = merge(var.tags, {
    cluster                    = var.cluster_name
    "karpenter.sh/discovery"   = var.cluster_name
  })

  # Control plane log types — audit is toggled by var.enable_audit_logs
  base_log_types  = ["api", "authenticator", "controllerManager", "scheduler"]
  audit_log_types = var.enable_audit_logs ? ["audit"] : []
  log_types       = concat(local.base_log_types, local.audit_log_types)
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# VPC — 3 public + 3 private subnets across 3 AZs
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + 4)]

  enable_nat_gateway     = true
  single_nat_gateway     = false   # One NAT per AZ — avoids cross-AZ traffic costs
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Tags required by EKS and Karpenter for subnet auto-discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"              = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"             = var.cluster_name
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Allow public kubectl access (matches jaseci-cluster)
  cluster_endpoint_public_access = true

  # OIDC — required for IRSA (EBS CSI, ALB controller)
  enable_irsa = true

  # Give the Terraform caller admin access automatically
  enable_cluster_creator_admin_permissions = true

  cluster_enabled_log_types = local.log_types

  # EKS managed add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # Managed nodegroup — always-on system nodes
  eks_managed_node_groups = {
    "${var.cluster_name}-ng" = {
      # Multiple types = fallback across AZs if one is capacity-constrained
      instance_types = var.node_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Rolling update: replace 1 node at a time during upgrades
      update_config = {
        max_unavailable = 1
      }

      # Nodes in private subnets only
      subnet_ids = module.vpc.private_subnets

      iam_role_use_name_prefix = false

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Taint system nodes so only daemonsets + Karpenter run here
      taints = {
        dedicated = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      labels = {
        role                             = "system"
        "alpha.eksctl.io/cluster-name"   = var.cluster_name
        "alpha.eksctl.io/nodegroup-name" = "${var.cluster_name}-ng"
      }
    }
  }

  # Tag the cluster security group for Karpenter discovery
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group — sets retention on the auto-created EKS log group
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = local.tags

  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# IRSA — VPC CNI
# ---------------------------------------------------------------------------
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "AmazonEKS_VPC_CNI_Role_${var.cluster_name}"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# IRSA — EBS CSI Driver
# ---------------------------------------------------------------------------
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "AmazonEKS_EBS_CSI_DriverRole_${var.cluster_name}"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}
