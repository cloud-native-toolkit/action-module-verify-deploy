#!/usr/bin/env bash

SRC_DIR="$1"

cd "${SRC_DIR}"

rm -rf "${SRC_DIR}/.terraform"
rm -rf "${SRC_DIR}/state"

echo ""

terraform init && terraform apply -auto-approve
