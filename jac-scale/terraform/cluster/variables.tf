variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "jac-builder-cluster2"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to use (3 recommended)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Managed nodegroup — system / always-on nodes
variable "node_instance_types" {
  description = "EC2 instance types for the managed nodegroup (first available wins)"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed nodegroup"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed nodegroup"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Initial desired number of nodes in the managed nodegroup"
  type        = number
  default     = 1
}

# Karpenter NodePool — dynamic workload nodes
variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.4.0"
}

variable "karpenter_instance_families" {
  description = "EC2 instance families Karpenter is allowed to provision"
  type        = list(string)
  default     = ["m", "t", "r"]
}

variable "karpenter_capacity_types" {
  description = "Capacity types Karpenter can use"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

# ---------------------------------------------------------------------------
# Audit logging
# ---------------------------------------------------------------------------
variable "enable_audit_logs" {
  description = "Enable EKS control plane audit logging to CloudWatch"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Retention period in days for the EKS CloudWatch log group"
  type        = number
  default     = 90
}

# ---------------------------------------------------------------------------
# EBS snapshot backups (DLM)
# ---------------------------------------------------------------------------
variable "enable_ebs_snapshots" {
  description = "Enable automated daily EBS snapshot backups via AWS DLM"
  type        = bool
  default     = false
}

variable "snapshot_retain_count" {
  description = "Number of daily EBS snapshots to retain"
  type        = number
  default     = 7
}

variable "snapshot_schedule_time" {
  description = "UTC time to run the daily snapshot (24h, e.g. '02:00')"
  type        = string
  default     = "02:00"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    environment = "production"
    team        = "jaseci"
  }
}
