#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

if [[ -f .bin_dir ]]; then
  BIN_DIR=$(cat .bin_dir)
fi

if [[ -f .kubeconfig ]]; then
  KUBECONFIG=$(cat .kubeconfig)
else
  KUBECONFIG="${PWD}/.kube/config"
fi
export KUBECONFIG

CLUSTER_TYPE="$1"
NAMESPACE="$2"
CONSOLE_LINK_NAME="$3"
VALIDATE_DEPLOY_SCRIPT="$4"

KUBECTL=$(command -v "${BIN_DIR}/kubectl" || command -v kubectl)

if [[ -z "${NAME}" ]]; then
  NAME=$(echo "${NAMESPACE}" | sed "s/tools-//")
fi

echo "Verifying resources in ${NAMESPACE} namespace for module ${NAME}"

if [[ -n "${VALIDATE_DEPLOY_SCRIPT}" ]] && [[ -f "${VALIDATE_DEPLOY_SCRIPT}" ]]; then
  echo "VALIDATE_DEPLOY_SCRIPT provided. Delegating validation logic to ${VALIDATE_DEPLOY_SCRIPT}"
  echo ""

  if ! ${VALIDATE_DEPLOY_SCRIPT} "${CLUSTER_TYPE}" "${NAMESPACE}" "${NAME}" "${CONSOLE_LINK_NAME}"; then
    echo "Validation failed"
    exit 1
  fi
else
  echo "No VALIDATE_DEPLOY_SCRIPT provided or script not found. Using default validation. (${VALIDATE_DEPLOY_SCRIPT})"
  echo ""

  PODS=$(${KUBECTL} get -n "${NAMESPACE}" pods -o jsonpath='{range .items[*]}{.status.phase}{": "}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | grep -v "Running" | grep -v "Succeeded")
  POD_STATUSES=$(echo "${PODS}" | sed -E "s/(.*):.*/\1/g")
  if [[ -n "${POD_STATUSES}" ]]; then
    echo "  Pods have non-success statuses: ${PODS}"
    exit 1
  fi

  set -e

  if [[ "${CLUSTER_TYPE}" == "kubernetes" ]] || [[ "${CLUSTER_TYPE}" =~ iks.* ]]; then
    ENDPOINTS=$(${KUBECTL} get ingress -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{range .spec.rules[*]}{.host}{"\n"}{end}{end}')
  else
    echo "Routes in namespace: ${NAMESPACE}"
    ${KUBECTL} get route -n "${NAMESPACE}"
    ENDPOINTS=$(${KUBECTL} get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.host}{.spec.path}{"\n"}{end}')
  fi

  echo "Validating endpoint urls:"
  echo "${ENDPOINTS}"

  ${KUBECTL} get route -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.host}{.spec.path}{"\n"}{end}' | while read endpoint; do
    if [[ -n "${endpoint}" ]]; then
      ${SCRIPT_DIR}/waitForEndpoint.sh "https://${endpoint}" 10 10
    fi
  done

  if [[ "${CLUSTER_TYPE}" =~ ocp4 ]] && [[ -n "${CONSOLE_LINK_NAME}" ]]; then
    echo "Validating consolelink"
    if [[ $(${KUBECTL} get consolelink "${CONSOLE_LINK_NAME}" | wc -l) -eq 0 ]]; then
      echo "   ConsoleLink not found"
      exit 1
    fi
  fi
fi

exit 0
