# Get current AWS account ID for policy conditions.
data "aws_caller_identity" "current" {}

# Create SNS topic used for pipeline notifications.
resource "aws_sns_topic" "this" {
  name = var.topic_name
  tags = var.tags
}

# Create one email subscription per configured email address.
resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_subscriptions)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}

# Build topic policy so account admins can manage the topic,
# and AWS services (CodePipeline/EventBridge) can publish messages.
data "aws_iam_policy_document" "topic_policy" {
  statement {
    sid    = "AllowAccountAdmin"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "sns:AddPermission",
      "sns:DeleteTopic",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:Publish",
      "sns:Receive",
      "sns:RemovePermission",
      "sns:SetTopicAttributes",
      "sns:Subscribe"
    ]
    resources = [
      aws_sns_topic.this.arn
    ]
  }

  statement {
    sid    = "AllowCodePipelinePublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sns:Publish"]
    resources = [
      aws_sns_topic.this.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sns:Publish"]
    resources = [
      aws_sns_topic.this.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Attach the generated SNS topic policy.
resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic_policy.json
}

