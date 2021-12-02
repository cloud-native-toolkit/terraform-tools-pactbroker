#!/usr/bin/env bash

CHART="$1"
NAMESPACE="$2"
INGRESS_HOST="$3"
DATABASE_TYPE="$4"
DATABASE_NAME="$5"
TLS_SECRET_NAME="$6"
INGRESS_ENABLED="$7"
ROUTE_ENABLED="$8"
CLUSTER_TYPE="$9"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR="./tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -z "${BIN_DIR}" ]]; then
  mkdir -p ./bin
  BIN_DIR=$(cd ./bin; pwd -P)
fi

HELM=$(command -v helm || command -v "${BIN_DIR}/helm")


NAME="pact-broker"
OUTPUT_YAML="${TMP_DIR}/pactbroker.yaml"
SECRET_OUTPUT_YAML="${TMP_DIR}/pactbroker-secret.yaml"

mkdir -p ${TMP_DIR}

VALUES=ingress.hosts.0.host=${INGRESS_HOST}
VALUES="${VALUES},ingress.enabled=${INGRESS_ENABLED}"
VALUES="${VALUES},route.enabled=${ROUTE_ENABLED}"
VALUES="${VALUES},ingress.tls[0].secretName=${TLS_SECRET_NAME}"
VALUES="${VALUES},ingress.tls[0].hosts[0]=${INGRESS_HOST}"
VALUES="${VALUES},ingress.annotations.ingress\.bluemix\.net/redirect-to-https='True'"

${HELM} repo add toolkit-charts "https://charts.cloudnativetoolkit.dev"
${HELM} repo update

kubectl config set-context --current --namespace "${NAMESPACE}"


echo "*** Generating kube yaml from helm template into ${OUTPUT_YAML}"
${HELM} template ${NAME} "${CHART}" \
    --namespace "${NAMESPACE}" \
    --set "${VALUES}" \
    --set database.type="${DATABASE_TYPE}" \
    --set database.name="${DATABASE_NAME}" > ${OUTPUT_YAML}

echo "*** Applying kube yaml ${OUTPUT_YAML}"
kubectl delete -n ${NAMESPACE} -f ${OUTPUT_YAML}

${HELM} template pactbroker-config toolkit-charts/tool-config \
  --namespace "${NAMESPACE}" \
  --set name=pactbroker \
  --set url="${URL}" > "${SECRET_OUTPUT_YAML}"

kubectl delete -n "${NAMESPACE}" -f "${SECRET_OUTPUT_YAML}"