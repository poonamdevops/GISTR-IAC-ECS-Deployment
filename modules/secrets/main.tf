# ---------------------------------------------------------------------------
# Module: secrets  (KMS key + Secrets Manager entries)
# ---------------------------------------------------------------------------
# Creates a customer-managed KMS key (used to encrypt EBS, ECR, secrets) and
# one Secrets Manager secret per app. Values start as PLACEHOLDERS and are
# updated with real (rotated) values once the client provides DB/Redis access.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS key policy: keep full admin for the account root, AND allow the
# CloudWatch Logs service to use the key so log groups can be encrypted.
data "aws_iam_policy_document" "kms" {
  # Account root retains full control of the key.
  statement {
    sid       = "EnableRootAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Allow CloudWatch Logs to use the key for encrypting log groups.
  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/gistr/*"]
    }
  }

  # Allow the Auto Scaling service-linked role to use the key for EBS
  # encryption. Required so ASG-launched EC2 instances can create their
  # encrypted root volumes (otherwise: Client.InvalidKMSKey.InvalidState).
  statement {
    sid = "AllowAutoScalingUseOfKey"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
  }

  # Auto Scaling also needs kms:CreateGrant (with the grant-for-AWS-resource
  # condition) to attach the encrypted volume to the instance.
  statement {
    sid       = "AllowAutoScalingCreateGrant"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

# ---- Customer-managed KMS key ---------------------------------------------
resource "aws_kms_key" "this" {
  description             = "${var.name_prefix} encryption key (EBS, ECR, secrets, logs)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-kms" })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name_prefix}"
  target_key_id = aws_kms_key.this.key_id
}

# ---- One secret per app ----------------------------------------------------
resource "aws_secretsmanager_secret" "app" {
  for_each = toset(var.app_names)

  name        = "/gistr/${var.environment}/${each.value}"
  description = "Application secrets for ${each.value} (${var.environment})"
  kms_key_id  = aws_kms_key.this.arn
  tags        = merge(var.tags, { Name = "${var.name_prefix}-${each.value}-secret", Application = each.value })
}

# Placeholder values. Real values (DB URL, Redis endpoint, API keys) are loaded
# later, out-of-band, so secrets never live in the Terraform code or state as
# real credentials.
resource "aws_secretsmanager_secret_version" "app" {
  for_each  = aws_secretsmanager_secret.app
  secret_id = each.value.id
  secret_string = jsonencode({
    PLACEHOLDER = "replace-with-real-values-after-client-db-access"
  })

  lifecycle {
    # Do not overwrite real values once they are set out-of-band.
    ignore_changes = [secret_string]
  }
}
