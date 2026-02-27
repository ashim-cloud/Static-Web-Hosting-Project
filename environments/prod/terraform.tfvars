aws_region              = "ap-southeast-1" # Singapore
project_name            = "DayNight" # Project name prefix for resource naming
github_owner            = "ashim-cloud" # GitHub Username
github_repo             = "daynight-web-prod" # GitHub Repository Name
github_branch           = "main" # GitHub Branch for production deployments

tags = {
  Application = "DayNight" # Must be included for resource management and tracking
  Owner       = "Ashim" # Must be included for resource management and tracking
  Environment = "production" # Must be included for resource management and tracking
  ManagedBy   = "terraform" # Must be included for resource management and tracking
}
