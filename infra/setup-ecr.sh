#!/bin/bash
# Create ECR repository and apply lifecycle / repository policies.
# Idempotent — safe to run multiple times.
#
# Required environment variables:
#   PROJECT_NAME  ECR repository name
#   REGION        AWS region

set -euo pipefail

: "${PROJECT_NAME:?PROJECT_NAME is required}"
: "${REGION:?REGION is required}"

REPO_NAME="${PROJECT_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/3] Creating ECR repository: ${REPO_NAME}"
aws ecr describe-repositories --repository-names "${REPO_NAME}" --region "${REGION}" >/dev/null 2>&1 || \
  aws ecr create-repository \
    --repository-name "${REPO_NAME}" \
    --image-scanning-configuration scanOnPush=true \
    --region "${REGION}"

echo "[2/3] Applying lifecycle policy"
aws ecr put-lifecycle-policy \
  --repository-name "${REPO_NAME}" \
  --region "${REGION}" \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep only the latest 2 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 2
      },
      "action": { "type": "expire" }
    }]
  }' >/dev/null

echo "[3/3] Applying repository policy (allow Lambda to pull)"
aws ecr set-repository-policy \
  --repository-name "${REPO_NAME}" \
  --region "${REGION}" \
  --policy-text "file://${SCRIPT_DIR}/ecr-repository-policy.json" >/dev/null

echo "Done. ECR repository '${REPO_NAME}' is ready."
