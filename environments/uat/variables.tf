# Input variables for the UAT environment.

variable "aws_region" {
  description = "Primary AWS region for UAT resources."
  type        = string
  default     = "ap-southeast-1" #Singapore
}

variable "project_name" {
  description = "Project name prefix used for resource naming."
  type        = string
}

variable "github_owner" {
  description = "GitHub owner/user."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_branch" {
  description = "GitHub branch name for UAT deployments."
  type        = string
  default     = "main"
}

variable "notification_emails" {
  description = "Email addresses subscribed to UAT pipeline notifications."
  type        = list(string)
  default     = []
}

# Controls whether the UAT CodePipeline module is created.
variable "enable_pipeline" {
  description = "Create UAT pipeline resources after SNS email subscription is confirmed."
  type        = bool
  default     = false
}

# Required tags used for naming, filtering, and ownership tracking.
variable "tags" {
  description = "Additional tags for UAT resources."
  type        = map(string)
  default     = {}

  validation {
    # These keys must always exist and have non-empty values.
    condition = alltrue([
      for key in ["Application", "Owner", "Environment", "ManagedBy"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must include non-empty values for Application, Owner, Environment, and ManagedBy."
  }
}

