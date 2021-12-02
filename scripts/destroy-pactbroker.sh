#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"
CHART="$3"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -z "${BIN_DIR}" ]]; then
  mkdir -p ./bin
  BIN_DIR=$(cd ./bin; pwd -P)
fi

HELM=$(command -v helm || command -v "${BIN_DIR}/helm")



${HELM} repo add toolkit-charts "https://charts.cloudnativetoolkit.dev"
${HELM} repo update

kubectl config set-context --current --namespace "${NAMESPACE}"

if [[ -n "${REPO}" ]]; then
  repo_config="--repo ${REPO}"
fi

#${HELM} template "${NAME}" "pactbroker-config" ${repo_config} --values "${VALUES_FILE}" | kubectl delete -f -

#${HELM} template "${NAME}" "${CHART}" ${repo_config} --values "${VALUES_FILE}" | kubectl delete -f -