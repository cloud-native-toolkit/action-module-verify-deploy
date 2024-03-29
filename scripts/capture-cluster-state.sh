#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)

if [[ -f .bin_dir ]]; then
  echo ".bin_dir found"
  BIN_DIR=$(cat .bin_dir)
  export PATH="${BIN_DIR}:${PATH}"
else
  echo ".bin_dir not found"
fi

export KUBECONFIG="${PWD}/.kube/config"

PLATFORM="$1"
INFILE_DIR="$2"
OUTFILE_DIR="$3"

mkdir -p "${OUTFILE_DIR}"

resources="deployment,statefulset,service,ingress,configmap,secret,serviceaccount"
if [[ "$PLATFORM" =~ ocp ]]; then
  resources="${resources},route"

  if [[ "$PLATFORM" =~ ocp4 ]]; then
    resources="${resources},consolelink"
  fi
fi

ls "${INFILE_DIR}" | while read infile; do
  NAMESPACE="${infile//.out/}"
  OUTFILE="${OUTFILE_DIR}/${infile}"

  echo "Checking on namespace - ${NAMESPACE}"

  if kubectl get namespace "${NAMESPACE}" 1> /dev/null 2> /dev/null; then
    echo "Listing resources in namespace - ${resources}"

    kubectl get -n "${NAMESPACE}" "${resources}" -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.kind}{"/"}{.metadata.name}{"\n"}{end}' | \
      tr '[:upper:]' '[:lower:]' > "${OUTFILE}"
  else
    echo "Namespace does not exist - ${NAMESPACE}"
    touch "${OUTFILE}"
  fi

  if kubectl get subscription -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; then
    kubectl get -n "${NAMESPACE}" subscription -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.kind}{"/"}{.metadata.name}{"\n"}{end}' 2> /dev/null | \
      tr '[:upper:]' '[:lower:]' >> "${OUTFILE}"
  fi

  cat "${OUTFILE}"
done
