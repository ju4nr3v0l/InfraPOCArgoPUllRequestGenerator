#!/usr/bin/env bash

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
LOCAL_PORT="${LOCAL_PORT:-8080}"

kubectl port-forward svc/argocd-server -n "${ARGOCD_NAMESPACE}" "${LOCAL_PORT}:443"
