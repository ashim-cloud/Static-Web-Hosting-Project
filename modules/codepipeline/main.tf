# IAM role used by CodePipeline service.
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.pipeline_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Inline IAM policy for source access, S3 deploy, Lambda invoke,
# SNS notifications, and optional promotion pipeline trigger.
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.pipeline_name}-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "UseCodeStarConnection"
          Effect = "Allow"
          Action = [
            "codestar-connections:UseConnection"
          ]
          Resource = var.connection_arn
        },
        {
          Sid    = "PipelineBucketAccess"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:GetBucketVersioning",
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::${var.app_bucket_name}",
            "arn:aws:s3:::${var.app_bucket_name}/*"
          ]
        },
        {
          Sid    = "InvokeInvalidationLambda"
          Effect = "Allow"
          Action = [
            "lambda:InvokeFunction"
          ]
          Resource = "arn:aws:lambda:*:*:function:${var.lambda_function_name}"
        },
        {
          Sid    = "ApprovalNotifications"
          Effect = "Allow"
          Action = [
            "sns:Publish"
          ]
          Resource = var.sns_topic_arn
        }
      ],
      var.enable_promotion_to_pipeline ? [
        {
          Sid    = "StartPromotionPipeline"
          Effect = "Allow"
          Action = [
            "codepipeline:StartPipelineExecution"
          ]
          Resource = "arn:aws:codepipeline:*:*:${var.promotion_pipeline_name}"
        }
      ] : []
    )
  })
}

# Main CodePipeline definition.
resource "aws_codepipeline" "this" {
  name          = var.pipeline_name
  role_arn      = aws_iam_role.codepipeline_role.arn
  pipeline_type = var.pipeline_type
  # Ensure IAM role policy exists before creating pipeline.
  depends_on = [aws_iam_role_policy.codepipeline_policy]

  # Use app S3 bucket as artifact store.
  artifact_store {
    location = var.app_bucket_name
    type     = "S3"
  }

  # Stage 1: pull code from GitHub through CodeStar connection.
  stage {
    name = "Source"

    action {
      name             = "SourceFromGitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = var.connection_arn
        FullRepositoryId     = "${var.github_owner}/${var.github_repo}"
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = tostring(var.source_detect_changes)
      }
    }
  }

  # Optional manual approval stage.
  dynamic "stage" {
    for_each = var.enable_manual_approval ? [1] : []
    content {
      name = "Approval"

      action {
        name      = "ManualApproval"
        category  = "Approval"
        owner     = "AWS"
        provider  = "Manual"
        version   = "1"
        run_order = 1

        configuration = {
          NotificationArn = var.sns_topic_arn
          CustomData      = "Approve deployment for ${var.pipeline_name}"
        }
      }
    }
  }

  # Stage 2: deploy built artifact to S3 website bucket.
  stage {
    name = "DeployToS3"

    action {
      name            = "S3Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        BucketName = var.app_bucket_name
        Extract    = "true"
      }
    }
  }

  # Stage 3: call Lambda to invalidate CloudFront cache.
  stage {
    name = "InvalidateCache"

    action {
      name     = "InvokeInvalidationLambda"
      category = "Invoke"
      owner    = "AWS"
      provider = "Lambda"
      version  = "1"

      configuration = {
        FunctionName   = var.lambda_function_name
        UserParameters = jsonencode({ paths = ["/*"] })
      }
    }
  }

  # Optional approval before triggering production pipeline.
  dynamic "stage" {
    for_each = var.enable_promotion_to_pipeline ? [1] : []
    content {
      name = "PromoteToProdApproval"

      action {
        name      = "ApproveProdTrigger"
        category  = "Approval"
        owner     = "AWS"
        provider  = "Manual"
        version   = "1"
        run_order = 1

        configuration = {
          NotificationArn = var.sns_topic_arn
          CustomData      = "UAT deployment succeeded. Approve to trigger production pipeline: ${var.promotion_pipeline_name}. URL: https://${var.cloudfront_domain_name}"
        }
      }
    }
  }

  # Optional stage to trigger downstream production pipeline.
  dynamic "stage" {
    for_each = var.enable_promotion_to_pipeline ? [1] : []
    content {
      name = "TriggerProdPipeline"

      action {
        name      = "StartProdPipeline"
        category  = "Invoke"
        owner     = "AWS"
        provider  = "CodePipeline"
        version   = "1"
        run_order = 1

        configuration = {
          PipelineName = var.promotion_pipeline_name
        }
      }
    }
  }

  tags = var.tags
}

# EventBridge rule for success notifications.
# If enabled, sends success after UAT Deploy+Invalidate action; otherwise after full pipeline success.
resource "aws_cloudwatch_event_rule" "pipeline_success" {
  name        = "${var.pipeline_name}-success"
  description = "Sends SNS notification when success condition is met."

  event_pattern = var.success_notification_after_uat_deploy ? jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Action Execution State Change"]
    detail = {
      pipeline = [var.pipeline_name]
      stage    = ["InvalidateCache"]
      action   = ["InvokeInvalidationLambda"]
      state    = ["SUCCEEDED"]
    }
    }) : jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [var.pipeline_name]
      state    = ["SUCCEEDED"]
    }
  })

  tags = var.tags
}

# Send success event to SNS with pipeline/execution details.
resource "aws_cloudwatch_event_target" "pipeline_success_sns" {
  rule      = aws_cloudwatch_event_rule.pipeline_success.name
  target_id = "PipelineSuccessToSNS"
  arn       = var.sns_topic_arn

  input_transformer {
    input_paths = {
      pipeline     = "$.detail.pipeline"
      execution_id = "$.detail.execution-id"
    }

    input_template = "\"Pipeline <pipeline> succeeded. CloudFront URL: https://${var.cloudfront_domain_name} (Execution: <execution_id>).\""
  }
}

# EventBridge rule for any failed pipeline action.
resource "aws_cloudwatch_event_rule" "pipeline_action_failed" {
  name        = "${var.pipeline_name}-action-failed"
  description = "Sends SNS notification when any pipeline action fails."

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Action Execution State Change"]
    detail = {
      pipeline = [var.pipeline_name]
      state    = ["FAILED"]
    }
  })

  tags = var.tags
}

# Send failure event to SNS with stage/action details.
resource "aws_cloudwatch_event_target" "pipeline_action_failed_sns" {
  rule      = aws_cloudwatch_event_rule.pipeline_action_failed.name
  target_id = "PipelineFailedToSNS"
  arn       = var.sns_topic_arn

  input_transformer {
    input_paths = {
      pipeline     = "$.detail.pipeline"
      stage        = "$.detail.stage"
      action       = "$.detail.action"
      execution_id = "$.detail.execution-id"
    }

    input_template = "\"Pipeline <pipeline> failed at stage '<stage>' (action: <action>). CloudFront URL: https://${var.cloudfront_domain_name} (Execution: <execution_id>).\""
  }
}
