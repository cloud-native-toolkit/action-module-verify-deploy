#!/usr/bin/env bash

SRC_DIR="$1"

cd "${SRC_DIR}"

rm -rf "${SRC_DIR}/.terraform"
rm -rf "${SRC_DIR}/state"

echo ""

PARALELLISM=10
if [[ "$REPO_NAME" == *"gitops"* ]]; then
  PARALELLISM=3
  echo "GitOps repo detected, using \"terraform -parallelism=$PARALELLISM\""
fi

if [[ -f terragrunt.hcl ]]; then
  terragrunt run-all apply --terragrunt-parallelism 1 --terragrunt-non-interactive
else
  terraform init && terraform apply -parallelism=$PARALELLISM -auto-approve
fi
