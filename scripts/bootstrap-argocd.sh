#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-argocd-poc}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGO_ROLLOUTS_NAMESPACE="${ARGO_ROLLOUTS_NAMESPACE:-argo-rollouts}"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind no esta instalado. Instala kind y vuelve a ejecutar este script."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl no esta instalado. Instala kubectl y vuelve a ejecutar este script."
  exit 1
fi

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --name "${CLUSTER_NAME}"
else
  echo "El cluster ${CLUSTER_NAME} ya existe."
fi

kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${ARGOCD_NAMESPACE}"

kubectl apply -n "${ARGOCD_NAMESPACE}" --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=Available deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl wait --for=condition=Available deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s

kubectl get namespace "${ARGO_ROLLOUTS_NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${ARGO_ROLLOUTS_NAMESPACE}"

kubectl apply -n "${ARGO_ROLLOUTS_NAMESPACE}" \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

kubectl wait --for=condition=Available deployment/argo-rollouts -n "${ARGO_ROLLOUTS_NAMESPACE}" --timeout=300s

echo "Argo CD instalado en el cluster ${CLUSTER_NAME}."
echo "Argo Rollouts instalado en el namespace ${ARGO_ROLLOUTS_NAMESPACE}."
