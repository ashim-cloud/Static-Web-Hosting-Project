aws_region              = "ap-southeast-1" # Singapore
project_name            = "DayNight" # Project name prefix for resource naming
github_owner            = "ashim-cloud" # GitHub Username
github_repo             = "daynight-web-prod" # GitHub Repository Name
github_branch           = "main" # GitHub Branch for production deployments
notification_emails     = ["ashimmunvar4@gmail.com"] # Emails for SNS notifications and CodePipeline manual approval
enable_pipeline = false

tags = {
  Application = "DayNight" # Must be included for resource management and tracking
  Owner       = "Ashim" # Must be included for resource management and tracking
  Environment = "UAT" # Must be included for resource management and tracking
  ManagedBy   = "terraform" # Must be included for resource management and tracking
}

# CodeConnection Create in Console and Add a Application Tag then Terraform Will Fetch the ARN by matching the tag value and use it in CodePipeline module.