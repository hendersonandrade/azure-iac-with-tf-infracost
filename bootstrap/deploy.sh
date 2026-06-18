#!/usr/bin/env bash
# =============================================================================
#  bootstrap/deploy.sh
#  Provisiona o backend de state do Terraform via Bicep — execução ÚNICA,
#  feita manualmente por um administrador (não pelo pipeline de aplicação).
#
#  Pré-requisitos:
#    - az login   (com permissão de Owner/Contributor na subscription)
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
