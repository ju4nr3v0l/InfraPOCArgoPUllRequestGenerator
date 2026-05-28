#!/usr/bin/env bash

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Debes exportar GITHUB_TOKEN antes de ejecutar este script."
  exit 1
fi

kubectl -n "${ARGOCD_NAMESPACE}" create secret generic github-token \
  --from-literal=token="${GITHUB_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret github-token creado o actualizado en ${ARGOCD_NAMESPACE}."
