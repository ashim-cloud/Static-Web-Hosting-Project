#!/usr/bin/env bash

# ============================================================
# Infra Orchestrator Script
# ------------------------------------------------------------
# This script manages full lifecycle of UAT and PROD Terraform
# environments with controlled execution flow.
#
# Deployment Order:
#   1. UAT
#   2. PROD
#   3. Email verification
#   4. Enable pipeline
#   5. Re-run UAT
#
# Destroy Order:
#   1. PROD
#   2. UAT
#   3. Reset pipeline flag to false
#
# Includes:
#   - Error handling
#   - Execution timing
#   - Structured logging
#   - Controlled destroy fallback
# ============================================================

set -u
set -o pipefail

# ============================================================
# Project Directory Configuration
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
UAT_DIR="$PROJECT_ROOT/environments/uat"
PROD_DIR="$PROJECT_ROOT/environments/prod"
TFVARS_FILE="$UAT_DIR/terraform.tfvars"

# Hardcoded email for verification display
EMAIL_ID="your-email@example.com"

# ============================================================
# Logging Configuration
# Logs will be stored under:
#   infra-orchestrator/logs/
# ============================================================

ORCHESTRATOR_DIR="$PROJECT_ROOT/infra-orchestrator"
LOG_DIR="$ORCHESTRATOR_DIR/logs"

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/execution_$(date +%Y%m%d_%H%M%S).log"

# Redirect all output (stdout + stderr) to log file and console
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Execution started at $(date)"
echo "Log file location: $LOG_FILE"

# ============================================================
# Start Time Tracking
# ============================================================

START_TIME=$(date +%s)

# ============================================================
# Utility Functions
# ============================================================

# ------------------------------------------------------------
# calculate_time
# Calculates total execution time in minutes and seconds
# ------------------------------------------------------------
calculate_time() {
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))

  echo "--------------------------------------------"
  echo "Total execution time: ${MINUTES} minutes ${SECONDS} seconds"
  echo "--------------------------------------------"
}

# ------------------------------------------------------------
# set_pipeline_flag
# Updates enable_pipeline value in terraform.tfvars
# ------------------------------------------------------------
set_pipeline_flag() {
  local VALUE=$1
  sed -i "s/enable_pipeline *= *.*/enable_pipeline = $VALUE/" "$TFVARS_FILE"
  echo "Updated enable_pipeline = $VALUE in terraform.tfvars"
}

# ------------------------------------------------------------
# deploy_env
# Runs terraform init and apply for given environment
# Returns failure if any command fails
# ------------------------------------------------------------
deploy_env() {
  local DIR=$1
  local NAME=$2

  echo "--------------------------------------------"
  echo "Deploying $NAME environment"
  echo "--------------------------------------------"

  cd "$DIR" || return 1

  terraform init || return 1
  terraform apply -auto-approve || return 1

  echo "$NAME deployment completed successfully."
}

# ------------------------------------------------------------
# destroy_env
# Runs terraform destroy for given environment
# Continues even if destroy fails
# ------------------------------------------------------------
destroy_env() {
  local DIR=$1
  local NAME=$2

  echo "--------------------------------------------"
  echo "Destroying $NAME environment"
  echo "--------------------------------------------"

  cd "$DIR" || return 1

  if ! terraform destroy -auto-approve; then
    echo "Destroy failed for $NAME. Manual action required."
    return 1
  fi

  echo "$NAME destroyed successfully."
}

# ------------------------------------------------------------
# email_verification
# Loops until user confirms email subscription
# After confirmation:
#   - Sets enable_pipeline = true
#   - Re-runs UAT deployment
# ------------------------------------------------------------
email_verification() {

  while true; do
    echo ""
    echo "Email verification required."
    echo "Configured notification email: $EMAIL_ID"
    echo "1) Yes, I have subscribed"
    echo "2) No, I have not subscribed"
    read -r CHOICE

    case $CHOICE in
      1)
        echo "Email subscription confirmed."

        # Enable pipeline
        set_pipeline_flag true

        echo "Re-executing UAT with pipeline enabled..."

        if ! deploy_env "$UAT_DIR" "UAT"; then
          echo "Error during re-execution of UAT."
          echo "Please debug manually."
          calculate_time
          exit 1
        fi

        break
        ;;
      2)
        echo "Please check inbox of $EMAIL_ID and confirm subscription."
        ;;
      *)
        echo "Invalid selection."
        ;;
    esac
  done
}

# ============================================================
# Main Execution Menu
# ============================================================

echo ""
echo "Select operation:"
echo "1) Create infrastructure"
echo "2) Destroy infrastructure"
read -r MAIN_CHOICE

# ============================================================
# Create Infrastructure Flow
# ============================================================

if [[ "$MAIN_CHOICE" == "1" ]]; then

  echo "Starting deployment process."

  # Step 1: Deploy UAT
  if ! deploy_env "$UAT_DIR" "UAT"; then
    echo "Error during UAT deployment."
    echo "Running cleanup for UAT."

    destroy_env "$UAT_DIR" "UAT"

    echo "Script encountered error. Debug manually."
    calculate_time
    exit 1
  fi

  # Step 2: Deploy PROD
  if ! deploy_env "$PROD_DIR" "PROD"; then
    echo "Error during PROD deployment."
    echo "Cleaning up environments."

    destroy_env "$PROD_DIR" "PROD"
    destroy_env "$UAT_DIR" "UAT"

    echo "Script encountered error. Debug manually."
    calculate_time
    exit 1
  fi

  # Step 3: Email verification
  email_verification

  echo "Infrastructure deployed successfully."

# ============================================================
# Destroy Infrastructure Flow
# ============================================================

elif [[ "$MAIN_CHOICE" == "2" ]]; then

  echo "Type YES (case-sensitive) to confirm destroy:"
  read -r CONFIRM

  if [[ "$CONFIRM" != "YES" ]]; then
    echo "Destroy aborted."
    exit 1
  fi

  DESTROY_ERROR=0

  # Destroy PROD first
  if ! destroy_env "$PROD_DIR" "PROD"; then
    DESTROY_ERROR=1
  fi

  # Destroy UAT next
  if ! destroy_env "$UAT_DIR" "UAT"; then
    DESTROY_ERROR=1
  fi

  # Reset pipeline flag after destroy
  set_pipeline_flag false

  if [[ $DESTROY_ERROR -eq 1 ]]; then
    echo "Destroy completed with errors. Please verify manually."
  else
    echo "Infrastructure destroyed successfully."
  fi

else
  echo "Invalid selection."
  exit 1
fi

# ============================================================
# Final Time Calculation
# ============================================================

calculate_time

echo "Execution finished."