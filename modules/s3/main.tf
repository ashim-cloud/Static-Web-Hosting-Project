# Get current AWS account ID for account-scoped policy conditions.
data "aws_caller_identity" "current" {}

# Create the S3 bucket for static site files.
resource "aws_s3_bucket" "this" {
  # Use prefix so AWS can generate a globally unique name when the base is unavailable.
  bucket_prefix = "${lower(var.bucket_name)}-"
  force_destroy = var.force_destroy
  tags          = var.tags
}

# Enable object versioning for safer rollbacks and recovery.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable default server-side encryption (SSE-S3/AES256).
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access at bucket level.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce bucket-owner object ownership (ACLs disabled).
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Build bucket policy:
# 1) deny non-HTTPS requests
# 2) optionally allow CloudFront service to read objects
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid = "DenyInsecureTransport"

    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_cloudfront_read_access ? [1] : []
    content {
      sid    = "AllowCloudFrontRead"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }

      actions = ["s3:GetObject"]

      resources = ["${aws_s3_bucket.this.arn}/*"]

      # Grants access only to CloudFront distributions in this account.
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }

      condition {
        test     = "ArnLike"
        variable = "AWS:SourceArn"
        values   = ["arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"]
      }
    }
  }
}

# Attach the generated bucket policy to the bucket.
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}
