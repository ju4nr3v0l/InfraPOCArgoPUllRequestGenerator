#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${1:-landing-prod}"
ROLLOUT_NAME="${2:-landingpage}"

if ! kubectl argo rollouts version >/dev/null 2>&1; then
  echo "No encuentro el plugin kubectl-argo-rollouts."
  echo "Instalalo con scripts/install-argo-rollouts-cli.sh"
  exit 1
fi

kubectl argo rollouts promote "${ROLLOUT_NAME}" -n "${NAMESPACE}"

echo "Promocion ejecutada para ${ROLLOUT_NAME} en ${NAMESPACE}."
