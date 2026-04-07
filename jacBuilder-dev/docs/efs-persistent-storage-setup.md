# EFS Persistent Storage for jac-builder

## Problem

All user project files are stored on the pod's ephemeral container filesystem (`/root/.jac-ide/`). When K8s reschedules the pod (OOM kill, node rotation, scaling event), the entire filesystem is wiped. The MongoDB graph still has metadata (project nodes) pointing to `repo_path` directories that no longer exist on disk, causing file saves to fail.

## Solution

Mount an EFS (Elastic File System) volume at `/root/.jac-ide/` — the default projects root used by `get_projects_root()` in `project_manager.jac`. EFS is NFS-based (ReadWriteMany), so it works correctly with any number of replicas (unlike EBS which is ReadWriteOnce).

No app code changes needed — `get_projects_root()` already defaults to `~/.jac-ide/projects/`, which is inside the EFS mount.

---

## Step-by-Step: Setting Up EFS on a New EKS Cluster

### Prerequisites

- AWS CLI configured with access to the target account
- `kubectl` configured for the target cluster
- EKS cluster with OIDC provider enabled

### Step 1: Collect Cluster Info

```bash
CLUSTER_NAME=jaseci-cluster   # change to your cluster name
REGION=us-east-2              # change to your region

# Get VPC and subnets
aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
  --query 'cluster.resourcesVpcConfig.{VpcId:vpcId,Subnets:subnetIds}'

# Identify private subnets (one per AZ, nodes run here)
aws ec2 describe-subnets --region $REGION \
  --subnet-ids <subnets from above> \
  --query 'Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value|[0]}'

# Get the ACTUAL node security group.
# Important: use the ClusterSharedNodeSecurityGroup, NOT the control-plane SG.
# Find it by inspecting any running cluster node:
aws ec2 describe-instances --region $REGION \
  --filters "Name=tag:aws:eks:cluster-name,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].{ID:GroupId,Name:GroupName}'

# Get OIDC ID
OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
  --query 'cluster.identity.oidc.issuer' --output text | cut -d'/' -f5)

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

For **jaseci-cluster** (us-east-2):

- VPC: `vpc-08dbde76269fe0c6b`
- Private subnets: `subnet-005fe76d653fef2f3` (2a), `subnet-02d5cb139fd801b41` (2b), `subnet-0e94f2b44ddb78d03` (2c)
- Node SG (ClusterSharedNodeSecurityGroup): `sg-026ff768549e18a90`
- OIDC ID: `E6F7D0EBE687557F676BFA6120BD13A5`
- Account: `776241927220`

---

### Step 2: Create EFS Security Group

Allow NFS (port 2049) inbound from the EKS node security group.

```bash
NODE_SG=<node SG from step 1>
VPC_ID=<VPC ID from step 1>

EFS_SG=$(aws ec2 create-security-group \
  --region $REGION \
  --group-name jaseci-efs-sg \
  --description "NFS access for jaseci-cluster EFS" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --region $REGION \
  --group-id $EFS_SG \
  --protocol tcp --port 2049 \
  --source-group $NODE_SG
```

For jaseci-cluster: EFS SG = `sg-0e0595c095123bed0`

---

### Step 3: Create EFS Filesystem

```bash
FS_ID=$(aws efs create-file-system \
  --region $REGION \
  --performance-mode generalPurpose \
  --throughput-mode elastic \
  --encrypted \
  --tags Key=Name,Value=jaseci-cluster-jac-builder Key=Cluster,Value=$CLUSTER_NAME \
  --query 'FileSystemId' --output text)
echo "EFS: $FS_ID"
```

For jaseci-cluster: `fs-0d908898724ff9a25`

---

### Step 4: Create Mount Targets (one per AZ, private subnets only)

```bash
for SUBNET in <private-subnet-2a> <private-subnet-2b> <private-subnet-2c>; do
  aws efs create-mount-target \
    --region $REGION \
    --file-system-id $FS_ID \
    --subnet-id $SUBNET \
    --security-groups $EFS_SG
done

# Wait ~1-2 min for all to reach 'available' state
aws efs describe-mount-targets --file-system-id $FS_ID --region $REGION \
  --query 'MountTargets[*].{State:LifeCycleState,Subnet:SubnetId}'
```

---

### Step 5: Install EFS CSI Driver

Check if already installed:

```bash
kubectl get pods -n kube-system | grep efs-csi
aws eks list-addons --cluster-name $CLUSTER_NAME --region $REGION
```

If not installed:

```bash
cat > /tmp/efs-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa",
        "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
      }
    }
  }]
}
EOF

aws iam create-role \
  --role-name AmazonEKS_EFS_CSI_DriverRole_JaseciCluster \
  --assume-role-policy-document file:///tmp/efs-trust-policy.json

aws iam attach-role-policy \
  --role-name AmazonEKS_EFS_CSI_DriverRole_JaseciCluster \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy

aws eks create-addon \
  --cluster-name $CLUSTER_NAME --region $REGION \
  --addon-name aws-efs-csi-driver \
  --service-account-role-arn arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EFS_CSI_DriverRole_JaseciCluster

# Wait ~2 min
kubectl get pods -n kube-system | grep efs-csi
```

---

### Step 6: Create EFS StorageClass

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${FS_ID}
  directoryPerms: "700"
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

The StorageClass (`efs-sc`) is cluster-wide and only needs to be created once. The PVC creation and deployment mounting are handled automatically by `deploy-dev.yml` on every CI run.

---

## Does this add time to every deploy?

No. `jac start --scale` uses `kubectl apply` (strategic merge), which preserves volumes added via `kubectl patch` since they're not in jac-scale's `last-applied-configuration`. The mount step checks first — on subsequent deploys it exits immediately with "already mounted, skipping". An extra rollout (~10 min) only happens:

- **Once**: the first deploy after adding the step to the workflow
- **If the deployment is deleted and recreated** from scratch on a fresh cluster

---

## AWS Resources (jaseci-cluster)

| Resource | ID/Name |
|---|---|
| EFS Filesystem | `fs-0d908898724ff9a25` |
| EFS Security Group | `sg-0e0595c095123bed0` |
| EFS CSI IAM Role | `AmazonEKS_EFS_CSI_DriverRole_JaseciCluster` |
| EFS CSI EKS Addon | `aws-efs-csi-driver` |
| K8s StorageClass | `efs-sc` (cluster-wide) |
| PVC (jac-builder-dev) | `jac-builder-dev-data-pvc` (10Gi RWX) |
