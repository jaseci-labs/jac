# ---------------------------------------------------------------------------
# Karpenter — IAM roles, SQS queue, Helm install, NodeClass, NodePool
# ---------------------------------------------------------------------------

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Use EKS Pod Identity (not IRSA) — matches jaseci-cluster
  enable_pod_identity             = true
  create_pod_identity_association = true

  # Node role — attached to every Karpenter-provisioned EC2 instance
  node_iam_role_name              = "KarpenterNodeRole-${var.cluster_name}"
  node_iam_role_use_name_prefix   = false

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Karpenter Helm install
# ---------------------------------------------------------------------------
resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version
  wait       = true

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  depends_on = [
    module.eks,
    module.karpenter,
  ]
}

# ---------------------------------------------------------------------------
# EC2NodeClass — defines what kind of EC2 instances Karpenter provisions
# ---------------------------------------------------------------------------
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
      annotations:
        kubernetes.io/description: "General purpose EC2NodeClass for AL2023 nodes"
    spec:
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.karpenter.node_iam_role_name}
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            deleteOnTermination: true
            volumeSize: 100Gi
            volumeType: gp3
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}

# ---------------------------------------------------------------------------
# NodePool — defines scheduling constraints and disruption policy
# ---------------------------------------------------------------------------
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: spot
      annotations:
        kubernetes.io/description: "NodePool for spot and on-demand capacity"
    spec:
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 10m
        budgets:
          - nodes: "10%"
      limits:
        cpu: 1000
        memory: 1000Gi
      template:
        spec:
          expireAfter: 720h
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          startupTaints:
            - key: karpenter.sh/uninitialized
              effect: NoSchedule
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ${jsonencode(var.karpenter_capacity_types)}
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ${jsonencode(var.karpenter_instance_families)}
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["2"]
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}
