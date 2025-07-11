#!/bin/bash

set -euo pipefail

# ----------------------------------------
# Defaults
# ----------------------------------------
AWS_REGION=""
AWS_PROFILE=""
EKS_CLUSTER_NAME=""
NAMESPACE=""

# ----------------------------------------
# Help
# ----------------------------------------
usage() {
  cat <<EOF
Usage: ekslogin [-p aws_profile] [-c cluster_name] [-r aws_region] [-n namespace]

Options:
  -p AWS_PROFILE      (required) AWS CLI profile name
  -c CLUSTER_NAME     (required) EKS cluster name
  -r AWS_REGION       (optional) AWS region (default: us-east-1)
  -n NAMESPACE        (optional) Default Kubernetes namespace
EOF
  exit 1
}

# ----------------------------------------
# Parse CLI args
# ----------------------------------------
while getopts ":p:c:r:n:" opt; do
  case $opt in
    p) AWS_PROFILE="$OPTARG" ;;
    c) EKS_CLUSTER_NAME="$OPTARG" ;;
    r) AWS_REGION="$OPTARG" ;;
    n) NAMESPACE="$OPTARG" ;;
    *) usage ;;
  esac
done

# ----------------------------------------
# Interactive prompts only if missing
# ----------------------------------------
[[ -z "$AWS_PROFILE" ]] && read -rp "Enter AWS profile: " AWS_PROFILE
[[ -z "$EKS_CLUSTER_NAME" ]] && read -rp "Enter EKS cluster name: " EKS_CLUSTER_NAME
[[ -z "$AWS_REGION" ]] && read -rp "Enter AWS region [default: us-east-1]: " AWS_REGION
AWS_REGION="${AWS_REGION:-us-east-1}"
[[ -z "$NAMESPACE" ]] && read -rp "Enter namespace (optional): " NAMESPACE

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
# Update kubeconfig
# ----------------------------------------
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME" \
  --profile "$AWS_PROFILE" || {
  echo "❌ Failed to update kubeconfig."
  exit 1
}

# ----------------------------------------
# Set default namespace
# ----------------------------------------
if [[ -n "$NAMESPACE" ]]; then
  kubectl config set-context --current --namespace "$NAMESPACE" || {
    echo "❌ Failed to set namespace context."
    exit 1
  }
fi

# ----------------------------------------
# Final confirmation
# ----------------------------------------
echo "✅ Successfully logged in to EKS cluster '$EKS_CLUSTER_NAME' using AWS profile '$AWS_PROFILE' in region '$AWS_REGION'."
