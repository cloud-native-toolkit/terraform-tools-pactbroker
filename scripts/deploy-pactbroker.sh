#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
MODULE_DIR=$(cd ${SCRIPT_DIR}/..; pwd -P)

CHART="$1"
NAMESPACE="$2"
INGRESS_HOST="$3"
DATABASE_TYPE="$4"
DATABASE_NAME="$5"
TLS_SECRET_NAME="$6"
INGRESS_ENABLED="$7"
ROUTE_ENABLED="$8"
CLUSTER_TYPE="$9"

if [[ -n "${KUBECONFIG_IKS}" ]]; then
    export KUBECONFIG="${KUBECONFIG_IKS}"
fi

if [[ -z "${TMP_DIR}" ]]; then
    TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ -z "${BIN_DIR}" ]]; then
  mkdir -p ./bin
  BIN_DIR=$(cd ./bin; pwd -P)
fi

HELM=$(command -v helm || command -v "${BIN_DIR}/helm")
JQ=$(command -v jq || command -v "${BIN_DIR}/jq")

if [[ -z "${HELM}" ]]; then
  curl -sLo helmx.tar.gz https://get.helm.sh/helm-v3.6.1-linux-amd64.tar.gz

  HELM=$(command -v helm || command -v "${BIN_DIR}/helm")

  if [[ -z "${HELM}" ]]; then
    mkdir helm.tmp && cd helm.tmp && tar xzf ../helmx.tar.gz

    HELM=$(command -v helm || command -v "${BIN_DIR}/helm")

    if [[ -z "${HELM}" ]]; then
      cp ./linux-amd64/helm "${BIN_DIR}/helm"

      HELM="${BIN_DIR}/helm"
    fi

    cd .. && rm -rf helm.tmp && rm helmx.tar.gz
  fi
fi

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

echo "*** Generating kube yaml from helm template into ${OUTPUT_YAML}"
${HELM} template ${NAME} "${CHART}" \
    --namespace "${NAMESPACE}" \
    --set "${VALUES}" \
    --set database.type="${DATABASE_TYPE}" \
    --set database.name="${DATABASE_NAME}" > ${OUTPUT_YAML}

echo "*** Applying kube yaml ${OUTPUT_YAML}"
kubectl apply -n ${NAMESPACE} -f ${OUTPUT_YAML} --validate=false

if [[ "${CLUSTER_TYPE}" == "openshift" ]] || [[ "${CLUSTER_TYPE}" == "ocp3" ]] || [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
  sleep 5

echo "*** DEBUGGING ***"
echo $JQ
which $JQ
ROUTE=$(oc get route pact-broker -n "${NAMESPACE}" -o json)
echo ROUTE

echo "using jq..."
PACTBROKER_HOST=$(echo ROUTE | $JQ ".spec.host" -r)
echo "*** END DEBUGGING ***"

  #PACTBROKER_HOST=$(oc get route pact-broker -n "${NAMESPACE}" -o=jsonpath="{.spec.host}")

  URL="https://${PACTBROKER_HOST}"
else
  PACTBROKER_HOST=$(kubectl get ingress/pact-broker -n "${NAMESPACE}" -o=jsonpath="{.spec.rules[0].host}")

  if [[ -n "${TLS_SECRET_NAME}" ]]; then
    URL="https://${PACTBROKER_HOST}"
  else
    URL="http://${PACTBROKER_HOST}"
  fi
fi



${HELM} template pactbroker-config toolkit-charts/tool-config \
  --namespace "${NAMESPACE}" \
  --set name=pactbroker \
  --set url="${URL}" > "${SECRET_OUTPUT_YAML}"

kubectl apply -n "${NAMESPACE}" -f "${SECRET_OUTPUT_YAML}"

echo "*** Waiting for Pact Broker"
"${SCRIPT_DIR}/waitForEndpoint.sh" "${URL}" 150 12
