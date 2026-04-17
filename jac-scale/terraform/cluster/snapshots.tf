# ---------------------------------------------------------------------------
# EBS Snapshot Backups via AWS DLM (Data Lifecycle Manager)
# Only created when var.enable_ebs_snapshots = true
# ---------------------------------------------------------------------------

# IAM role that DLM service assumes to create/delete snapshots
resource "aws_iam_role" "dlm" {
  count = var.enable_ebs_snapshots ? 1 : 0

  name = "DLMRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "dlm" {
  count = var.enable_ebs_snapshots ? 1 : 0

  role       = aws_iam_role.dlm[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

# DLM lifecycle policy — daily snapshot of all EBS volumes tagged with this cluster
resource "aws_dlm_lifecycle_policy" "ebs" {
  count = var.enable_ebs_snapshots ? 1 : 0

  description        = "Daily EBS snapshots for ${var.cluster_name}"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    # Target volumes tagged with the cluster name
    target_tags = {
      cluster = var.cluster_name
    }

    schedule {
      name = "Daily-${var.cluster_name}"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.snapshot_schedule_time]
      }

      retain_rule {
        count = var.snapshot_retain_count
      }

      # Snapshots inherit all tags from the source volume
      copy_tags = true

      tags_to_add = {
        cluster     = var.cluster_name
        managed-by  = "dlm"
      }
    }
  }

  tags = local.tags
}
