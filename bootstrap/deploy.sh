#!/usr/bin/env bash
# =============================================================================
#  bootstrap/deploy.sh
#  Provisiona o backend de state do Terraform via Bicep. É o entrypoint do
#  workflow bootstrap-tfstate.yml e também pode ser usado localmente para debug.
#
#  Pré-requisitos:
#    - sessão Azure autenticada (OIDC no pipeline ou az login local)
#    - storageAccountName GLOBALMENTE único em main.parameters.json
# =============================================================================
set -euo pipefail

LOCATION="${LOCATION:-brazilsouth}"
DEPLOYMENT_NAME="tfstate-bootstrap-$(date +%Y%m%d%H%M%S)"

echo "==> Validando o template Bicep..."
az deployment sub validate \
  --location "$LOCATION" \
  --template-file main.bicep \
  --parameters @main.parameters.json

echo "==> Implantando o backend de state (escopo: subscription)..."
az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file main.bicep \
  --parameters @main.parameters.json

echo "==> Pronto. Outputs:"
az deployment sub show \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs \
  --output jsonc
