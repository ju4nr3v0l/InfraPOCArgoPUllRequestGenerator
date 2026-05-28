#!/usr/bin/env bash

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew no esta instalado. Instala brew o el plugin kubectl-argo-rollouts manualmente."
  exit 1
fi

brew install argoproj/tap/kubectl-argo-rollouts

echo "kubectl-argo-rollouts instalado."
echo "Prueba con: kubectl argo rollouts version"
