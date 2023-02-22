#! /bin/bash

if [[ -f terragrunt.hcl ]]; then
  terragrunt run-all destroy --terragrunt-parallelism 1 --terragrunt-non-interactive --terragrunt-ignore-dependency-errors
  
  exit 1
fi

echo ""
echo "Listing current state"
terraform state list

echo ""
echo "Collecting resources to destroy"
RESOURCE_LIST=""
while read -r resource; do
  echo "  Adding $resource to destroy targets"
  RESOURCE_LIST="$RESOURCE_LIST -target=$resource"
done < <(terraform state list | grep -v "module.dev_cluster" | grep -v "module.dev_software_olm" | grep -v "module.dev_tools_namespace")

if [[ -n "$RESOURCE_LIST" ]]; then
  echo ""
  echo "Planning destroy"
  terraform plan -destroy ${RESOURCE_LIST} -out=destroy.plan

  echo ""

  PARALELLISM=10
  if [[ "$REPO_NAME" == *"gitops"* ]]; then
    PARALELLISM=3
    echo "GitOps repo detected, using \"terraform -parallelism=$PARALELLISM\""
  fi

  echo "Destroying resources"
  terraform apply -parallelism=$PARALELLISM -auto-approve destroy.plan
else
  echo ""
  echo "Nothing to destroy!!"
fi
