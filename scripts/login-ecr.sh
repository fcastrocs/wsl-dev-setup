#!/bin/bash

set -euo pipefail

# ----------------------------------------
# Defaults
# ----------------------------------------
AWS_REGION=""
AWS_PROFILE=""
AWS_ACCOUNT_ID=""

# ----------------------------------------
# Help
# ----------------------------------------
usage() {
  cat <<EOF
Usage: ecrlogin [-p aws_profile] [-a aws_account_id] [-r aws_region]

Options:
  -p AWS_PROFILE      (required) AWS CLI profile name
  -a AWS_ACCOUNT_ID   (required) AWS account ID
  -r AWS_REGION       (optional) AWS region (default: us-east-1)
EOF
  exit 1
}

# ----------------------------------------
# Parse CLI args
# ----------------------------------------
while getopts ":p:a:r:" opt; do
  case $opt in
    p) AWS_PROFILE="$OPTARG" ;;
    a) AWS_ACCOUNT_ID="$OPTARG" ;;
    r) AWS_REGION="$OPTARG" ;;
    *) usage ;;
  esac
done

# ----------------------------------------
# Interactive prompts only if missing
# ----------------------------------------
[[ -z "$AWS_PROFILE" ]] && read -rp "Enter AWS profile: " AWS_PROFILE
[[ -z "$AWS_ACCOUNT_ID" ]] && read -rp "Enter AWS account ID: " AWS_ACCOUNT_ID
[[ -z "$AWS_REGION" ]] && read -rp "Enter AWS region [default: us-east-1]: " AWS_REGION
AWS_REGION="${AWS_REGION:-us-east-1}"

ECR_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# ----------------------------------------
# AWS login check
# ----------------------------------------
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
  if ! aws sso login --profile "$AWS_PROFILE"; then
    echo "❌ AWS SSO login failed."
    exit 1
  fi
fi

# ----------------------------------------
# Authenticate Docker with ECR
# ----------------------------------------
if ! aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" \
  | docker login --username AWS --password-stdin "$ECR_REPO_URI" >/dev/null 2>&1; then
  echo "❌ Docker authentication to ECR failed."
  exit 1
fi

# ----------------------------------------
# Final confirmation
# ----------------------------------------
echo "✅ Successfully authenticated Docker to ECR registry '$ECR_REPO_URI' using AWS profile '$AWS_PROFILE'."
