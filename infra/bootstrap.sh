#!/bin/bash
# One-shot AWS / GitHub setup for the template.
# Idempotent — safe to run multiple times.
#
# Edit PROJECT_NAME / GITHUB_REPO / REGION below (or pass via env), then run:
#   ./infra/bootstrap.sh
#
# Prerequisites:
#   - AWS CLI authenticated (aws sts get-caller-identity passes)
#   - gh CLI authenticated (gh auth status passes)

set -euo pipefail

# ===== EDIT THESE =====
PROJECT_NAME="${PROJECT_NAME:-myapp}"
GITHUB_REPO="${GITHUB_REPO:-yourname/myapp}"
REGION="${REGION:-ap-northeast-1}"
# ======================

ROLE_NAME="${PROJECT_NAME}-github-actions"
POLICY_NAME="${PROJECT_NAME}-github-actions-policy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 0. Preflight ----------
echo "[0/5] Preflight"
command -v aws >/dev/null 2>&1 || { echo "  ERROR: aws CLI not found (brew install awscli)"; exit 1; }
command -v gh  >/dev/null 2>&1 || { echo "  ERROR: gh CLI not found (brew install gh)";   exit 1; }
aws sts get-caller-identity --region "${REGION}" >/dev/null 2>&1 || { echo "  ERROR: AWS not authenticated (aws configure)"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "  ERROR: gh CLI not authenticated (gh auth login)"; exit 1; }

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
echo "  Project: ${PROJECT_NAME}"
echo "  GitHub: ${GITHUB_REPO}"
echo "  Region: ${REGION}"
echo "  Account: ${ACCOUNT_ID}"

# ---------- 1. GitHub OIDC Identity Provider ----------
echo "[1/5] GitHub OIDC Identity Provider"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1; then
  echo "  exists, skipping"
else
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
    --tags Key=Project,Value="${PROJECT_NAME}" >/dev/null
  echo "  created"
fi

# ---------- 2. IAM Role ----------
echo "[2/5] IAM Role: ${ROLE_NAME}"
TRUST_POLICY="$(sed \
  -e "s|__ACCOUNT_ID__|${ACCOUNT_ID}|g" \
  -e "s|__GITHUB_REPO__|${GITHUB_REPO}|g" \
  "${SCRIPT_DIR}/github-actions-trust-policy.json")"
INLINE_POLICY="$(sed \
  -e "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
  -e "s|__REGION__|${REGION}|g" \
  "${SCRIPT_DIR}/github-actions-policy.json")"

if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "  exists, updating trust + inline policy"
  aws iam update-assume-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-document "${TRUST_POLICY}" >/dev/null
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "GitHub Actions OIDC role for ${PROJECT_NAME}" \
    --tags Key=Project,Value="${PROJECT_NAME}" >/dev/null
  echo "  created"
fi
aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "${POLICY_NAME}" \
  --policy-document "${INLINE_POLICY}" >/dev/null
echo "  inline policy applied"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# ---------- 3. ECR repository ----------
echo "[3/5] ECR repository (${PROJECT_NAME})"
PROJECT_NAME="${PROJECT_NAME}" REGION="${REGION}" "${SCRIPT_DIR}/setup-ecr.sh"

# ---------- 4. GitHub Variables ----------
echo "[4/5] GitHub Variables: AWS_ROLE_ARN / PROJECT_NAME / AWS_REGION"
gh variable set AWS_ROLE_ARN  --body "${ROLE_ARN}"      --repo "${GITHUB_REPO}"
gh variable set PROJECT_NAME  --body "${PROJECT_NAME}"  --repo "${GITHUB_REPO}"
gh variable set AWS_REGION    --body "${REGION}"        --repo "${GITHUB_REPO}"

# ---------- 5. Done ----------
echo "[5/5] Done"
echo ""
echo "=========================================="
echo "Bootstrap complete!"
echo "  AWS Role ARN: ${ROLE_ARN}"
echo ""
echo "Next:"
echo "  1. Push to main, or run 'Deploy Lambda + Static Frontend' on GitHub Actions."
echo "  2. After deploy:"
echo "     DOMAIN=\$(aws cloudformation describe-stacks --stack-name ${PROJECT_NAME} --region ${REGION} --query 'Stacks[0].Outputs[?OutputKey==\`DistributionDomainName\`].OutputValue' --output text)"
echo "     curl \"https://\${DOMAIN}/api/health\""
echo "=========================================="
