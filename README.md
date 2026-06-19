# Azure IaC with Terraform and Infracost for FinOps (Shift-Left)

> Laboratório **enterprise** de Infraestrutura como Código (IaC) no Azure com **Terraform**,
> pipeline **GitHub Actions** autenticado por **OpenID Connect (Workload Identity Federation)**,
> backend de state provisionado via **Bicep**, e estimativa de custo (**FinOps**) com **Infracost**
> comentada automaticamente em cada Pull Request.

Este repositório é o **companion prático** do artigo
[**Azure + Terraform + Infracost: IaC enterprise com FinOps no pipeline**](https://hendersonandrade.github.io/blog/azure-terraform-infracost.pt-br.html).

- O **artigo** explica os **conceitos e o porquê** (IaC, FinOps, OIDC, por que o state vai via Bicep).
- **Este README é o guia prático, passo a passo, do como** — do `git clone` ao `terraform destroy`.

---

## Índice

1. [Visão geral da esteira](#visão-geral-da-esteira)
2. [Estrutura do repositório](#estrutura-do-repositório)
3. [Como as peças se encaixam](#como-as-peças-se-encaixam)
4. [Pré-requisitos](#pré-requisitos)
5. [Passo 1 — Clonar o repositório](#passo-1--clonar-o-repositório)
6. [Passo 2 — Identidade federada (OIDC)](#passo-2--criar-a-identidade-federada-oidc--sem-segredos)
7. [Passo 3 — Variables e Secrets no GitHub](#passo-3--configurar-variables-e-secrets-no-github)
8. [Passo 4 — Backend de state pelo pipeline](#passo-4--provisionar-o-backend-de-state-pelo-pipeline)
9. [Passo 5 — Rodar localmente (opcional)](#passo-5--opcional-rodar-localmente-antes-do-pipeline)
10. [Passo 6 — Pull Request + Infracost](#passo-6--abrir-um-pull-request-e-ver-o-custo-infracost)
11. [Passo 7 — Merge e apply](#passo-7--fazer-merge-e-aplicar-com-aprovação)
12. [Passo 8 — Infracost Cloud](#passo-8--conferir-o-custo-no-infracost-cloud-opcional)
13. [Passo 9 — Destruir o laboratório](#passo-9--destruir-o-laboratório-evita-custo-esquecido)
14. [Como customizar](#como-customizar)
15. [Custo de referência](#custo-de-referência-do-laboratório)
16. [Solução de problemas](#solução-de-problemas)
17. [FAQ](#faq)
18. [Referências](#referências)

---

## Visão geral da esteira

```
            ┌──────────────────────── GitHub ──────────────────────────┐
            │                                                          │
  git push  │   Pull Request                     Push na main          │
     ─────> ├─ terraform fmt / validate                                │
            │   ├─ terraform plan                                      │
            │   ├─ Infracost: custo comentado no PR                    │
            │   └─ (sem aplicar)                  ├─ terraform apply ──┼──┐
            │                                     └─ aprovação manual  │  │
            └──────────┬───────────────────────────────────┬───────────┘  │
                       │ token OIDC (sem segredos)         │ token OIDC   │
                       ▼                                   ▼              ▼
                  ┌─────────┐                          ┌─────────┐  ┌─────────┐
                  │ Entra ID│ ── access token curto ─> │ Azure RM│  │ Azure   │
                  │ (WIF)   │                          └─────────┘  │ recursos│
                  └─────────┘                                       └─────────┘

  workflow bootstrap ─▶ Bicep ─▶ Storage Account do state (fora do ciclo do Terraform)
```

**Recursos provisionados** pela stack Terraform (`infra/`):

| Módulo | Recurso | Observações |
| --- | --- | --- |
| `modules/networking` | VNet + subnet + NSG | NSG associado à subnet; SSH liberado só de `10.0.0.0/8` |
| `modules/storage-account` | 1 Storage Account | TLS 1.2, sem acesso público, versionamento de blob, sufixo aleatório p/ nome único |
| `modules/virtual-machine` | 1 VM Linux Ubuntu 24.04 + NIC | sem IP público (acesso via Bastion/VPN); chave SSH gerada |
| `modules/app-service` | 1 App Service Plan (Linux) + Web App | HTTPS-only, identidade gerenciada (system-assigned) |

---

## Estrutura do repositório

```
azure-iac-with-tf-infracost/
│
├── bootstrap/                      # ► PASSO 4 — backend de state (Bicep, execução única)
│   ├── main.bicep                  #   escopo subscription: cria RG + chama o módulo
│   ├── modules/
│   │   └── state-storage.bicep     #   Storage Account endurecida + container "tfstate"
│   ├── main.parameters.json        #   parâmetros (EDITE o storageAccountName!)
│   └── deploy.sh                    #   roda `az deployment sub create`
│
├── infra/                          # ► raiz Terraform aplicada pelo pipeline
│   ├── providers.tf                #   versões + backend "azurerm" remoto (OIDC)
│   ├── main.tf                     #   cria o RG e compõe os 4 módulos
│   ├── variables.tf                #   entradas da stack (com validações)
│   ├── outputs.tf                  #   saídas (nome do RG, IP da VM, hostname...)
│   ├── data.tf                     #   data sources (client_config, subscription)
│   ├── dev.tfvars                  #   valores do ambiente dev (barato)
│   └── prod.tfvars                 #   valores do ambiente prod (SKUs maiores)
│
├── modules/                        # ► módulos reutilizáveis (1 responsabilidade cada)
│   ├── networking/                 #   variables.tf · main.tf · outputs.tf
│   ├── storage-account/
│   ├── virtual-machine/
│   └── app-service/
│
├── infracost/
│   └── infracost.yml               # ► quais projetos/var-files custar (dev + prod)
│
├── .github/workflows/
│   ├── bootstrap-tfstate.yml       # ► cria o backend via Bicep + OIDC
│   └── terraform.yml               # ► plan (PR/push) + apply (main)
│
├── .gitignore                      # ignora .terraform/, *.tfstate, infracost.json...
└── README.md                       # este guia
```

> **Por que `bootstrap/` é separado de `infra/`?** São dois ciclos de vida distintos: o
> backend de state é criado **uma vez** pelo workflow dedicado (com Bicep, que não tem state
> próprio), e a partir daí a stack `infra/` é aplicada **continuamente** pelo outro workflow. Misturar
> os dois recria o problema do "ovo e galinha" do state. Veja a explicação completa no
> [artigo](https://hendersonandrade.github.io/blog/azure-terraform-infracost.pt-br.html#backend-bicep).

---

## Como as peças se encaixam

**1. O state remoto.** O Terraform guarda o `tfstate` (mapa entre código e recursos reais) num
backend `azurerm` — a Storage Account criada no Passo 4. Como o bloco `backend` não aceita
variáveis, o nome do RG e da Storage Account são passados em tempo de `init` via `-backend-config`
(o pipeline lê esses valores diretamente de `bootstrap/main.parameters.json`).

**2. Autenticação sem segredos (OIDC).** Em vez de uma client secret guardada, o GitHub Actions
emite um **token OIDC** de curta duração por execução. O Entra ID confia nesse token graças a um
**Federated Credential** ligado ao `subject` do repositório (`repo:org/repo:ref:refs/heads/main`
para push, `repo:org/repo:pull_request` para PRs). Tanto o `provider "azurerm"` quanto o `backend`
usam `use_oidc = true`.

**3. A composição modular.** A raiz `infra/main.tf` cria o resource group e injeta entradas em
cada módulo. Saídas de um módulo viram entradas de outro — ex.: `module.networking.subnet_id`
alimenta o módulo da VM. Cada módulo tem o contrato `variables.tf` (entradas) / `main.tf`
(recursos) / `outputs.tf` (saídas).

**4. O FinOps no PR.** No job de PR, o Infracost gera o **diff** de custo a partir do plano e
comenta no Pull Request. Tags comuns (`environment`, `managedBy`, `costCenter`) em todos os
recursos garantem a atribuição de custo ao dono certo.

---

## Pré-requisitos

Confira as versões antes de começar:

| Ferramenta | Como instalar | Verificar |
| --- | --- | --- |
| **Azure CLI** | [docs](https://learn.microsoft.com/cli/azure/install-azure-cli) | `az version` |
| **Terraform** ≥ 1.7 | [docs](https://developer.hashicorp.com/terraform/install) | `terraform version` |
| **Infracost CLI** | [docs](https://www.infracost.io/docs/) | `infracost --version` |
| **Git** | [docs](https://git-scm.com/downloads) | `git --version` |

E também:

- [ ] Uma **subscription Azure** com permissão de **Owner** (ou Contributor + User Access Administrator,
      necessário para criar a *role assignment* do Passo 2).
- [ ] Uma conta no **GitHub** e permissão para criar Secrets/Variables/Environments no repositório
      (faça um *fork* deste repo, se preferir).
- [ ] Uma conta gratuita no **Infracost** (gera a `INFRACOST_API_KEY`).

> ⚠️ **Aviso de custo:** este laboratório provisiona recursos que **geram custo real**
> (~US$ 45–55/mês em dev). Não esqueça o **Passo 9** (destroy) ao terminar.

---

## Passo 1 — Clonar o repositório

```bash
git clone https://github.com/hendersonandrade/azure-iac-with-tf-infracost.git
cd azure-iac-with-tf-infracost
```

> Se você fez um **fork**, troque a URL pelo seu `org/repo`. Isso importa: o `subject` do
> federated credential (Passo 2) precisa casar com o **seu** repositório.

---

## Passo 2 — Criar a identidade federada (OIDC / sem segredos)

Cria um **App Registration** no Entra ID e **dois Federated Credentials** (um para a branch
`main`, outro para Pull Requests) — **sem nenhuma client secret**. A credencial da `main`
autentica tanto o bootstrap do state quanto o `terraform apply`.

**2.1 — Confirme a sessão e a subscription usadas no bootstrap do OIDC:**

Esta autenticação administrativa é necessária apenas para a configuração inicial da identidade.
O pipeline ainda não pode usar OIDC porque o App Registration e os Federated Credentials serão
criados nos próximos passos. Se a Azure CLI já estiver autenticada e apontando para a subscription
correta, pule os dois primeiros comandos e apenas confirme o contexto com `az account show`.

```bash
az login                                      # somente se não houver uma sessão ativa
az account set --subscription "<SUBSCRIPTION_ID>"  # somente se precisar trocar a subscription
az account show --output table
```

**2.2 — Crie o app e o service principal:**

```bash
appId=$(az ad app create --display-name "gh-azure-iac-tf" --query appId -o tsv)
az ad sp create --id "$appId"
echo "AZURE_CLIENT_ID = $appId"          # guarde este valor
```

**2.3 — Credencial federada para a `main`** (bootstrap e push → apply):

```bash
az ad app federated-credential create --id "$appId" --parameters '{
  "name": "gh-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:hendersonandrade/azure-iac-with-tf-infracost:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

**2.4 — Credencial federada para Pull Requests** (PR → plan + Infracost):

```bash
az ad app federated-credential create --id "$appId" --parameters '{
  "name": "gh-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:hendersonandrade/azure-iac-with-tf-infracost:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

**2.5 — Dê permissão ao service principal na subscription:**

```bash
subId=$(az account show --query id -o tsv)
az role assignment create --assignee "$appId" \
  --role "Contributor" \
  --scope "/subscriptions/$subId"
```

> 💡 **Atenção ao `subject`.** Ele precisa casar **exatamente** com o seu `org/repo` e o gatilho.
> Se você fez fork, troque `hendersonandrade/azure-iac-with-tf-infracost` pelo seu. Um `subject`
> errado é a causa nº 1 de falha de login OIDC no pipeline.

---

## Passo 3 — Configurar Variables e Secrets no GitHub

No repositório: **Settings → Secrets and variables → Actions**.

**3.1 — Defina o backend e as Variables.** Primeiro ajuste `bootstrap/main.parameters.json`.
O `storageAccountName` deve ser globalmente único (3–24 caracteres, somente minúsculas e
dígitos):

```jsonc
{
  "parameters": {
    "location":           { "value": "brazilsouth" },
    "resourceGroupName":  { "value": "rg-tfstate-prod" },
    "storageAccountName": { "value": "sttfstateabc12345" },
    "containerName":      { "value": "tfstate" }
  }
}
```

O pipeline usa esse arquivo como fonte única de verdade para `resourceGroupName` e
`storageAccountName`; não é necessário duplicar esses valores como Variables do GitHub.
Na aba *Variables*, cadastre somente os dados da identidade OIDC:

| Nome | Valor | De onde vem |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | o `appId` | Passo 2.2 |
| `AZURE_TENANT_ID` | seu tenant | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | id da subscription | `az account show --query id -o tsv` |

**3.2 — Obter a `INFRACOST_API_KEY`.**

A API key é **gratuita** e identifica a sua conta junto à Cloud Pricing API (é ela que faz a
busca de preços). Há duas formas de obtê-la:

**Forma A — pela CLI (recomendada).** O comando abre o navegador, você cria/entra na conta
Infracost e a CLI grava a chave localmente:

```bash
infracost auth login
```

Saída esperada:

```text
Please visit the following URL to authenticate: https://dashboard.infracost.io/login?cli=...
Waiting...
Success! You are now logged in.
```

Depois, **leia a chave** para copiá-la:

```bash
infracost configure get api_key
# ► ico-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> A chave fica salva em `~/.config/infracost/credentials.yml` (Linux/macOS) ou
> `%USERPROFILE%\.config\infracost\credentials.yml` (Windows). Trate-a como segredo —
> **não** a comite no repositório.

**Forma B — pelo dashboard.** Acesse [dashboard.infracost.io](https://dashboard.infracost.io/) →
**Org Settings → API keys** e copie a chave de lá.

> 🔑 **Pessoal vs. da organização.** O `infracost auth login` te dá uma chave **pessoal**, ótima
> para o lab. Em times, prefira uma chave da **organização** (no Infracost Cloud) para que os
> custos de todos os repositórios sejam agregados no mesmo dashboard.

**3.3 — Cadastrar a chave como Secret no GitHub** (aba *Secrets* → *New repository secret*):

| Nome | Valor | De onde vem |
| --- | --- | --- |
| `INFRACOST_API_KEY` | a chave `ico-...` | Passo 3.2 (`infracost configure get api_key`) |

> No workflow, essa Secret é injetada na action `infracost/actions/setup@v3` via
> `with: { api-key: ${{ secrets.INFRACOST_API_KEY }} }` — é o único segredo do pipeline (o resto é
> OIDC, sem segredos). Para **rodar o Infracost localmente** (Passo 5/6) você não precisa exportá-la
> de novo: a CLI já a lê de `credentials.yml`. Em CI, se preferir uma variável de ambiente em vez da
> action, exporte `INFRACOST_API_KEY=${{ secrets.INFRACOST_API_KEY }}`.

**3.4 — Environment de produção** (**Settings → Environments → New environment**):

- Crie um environment chamado exatamente **`production`**.
- Marque **Required reviewers** e adicione você mesmo. É isso que faz o job `apply` **pausar e
  esperar aprovação** antes de tocar no Azure.

---

## Passo 4 — Provisionar o backend de state pelo pipeline

O Terraform precisa da Storage Account antes do primeiro `terraform init`. Ela continua sendo
declarada em Bicep para não criar uma dependência circular de state, mas agora a criação é feita
pelo workflow dedicado, com a mesma autenticação OIDC sem segredos usada pelo Terraform.

Em todo push relevante na `main`, o pipeline `terraform` chama primeiro o workflow reutilizável
`bootstrap tfstate` e só libera o `terraform init` depois que o backend estiver pronto. Isso evita
uma corrida entre a criação da Storage Account e o job de plan. Para reaplicar o backend sob
demanda:

1. Abra **Actions → bootstrap tfstate → Run workflow**.
2. Selecione a branch **`main`** e confirme em **Run workflow**.
3. Acompanhe os passos de login OIDC, validação e implantação.

Se preferir disparar pela GitHub CLI:

```bash
gh workflow run bootstrap-tfstate.yml --ref main
gh run watch
```

O deployment é **idempotente**: executá-lo novamente com os mesmos parâmetros mantém o backend
existente. Ao final, o log exibe os outputs usados pelo Terraform:

```jsonc
{
  "containerName":      { "type": "String", "value": "tfstate" },
  "resourceGroupName":  { "type": "String", "value": "rg-tfstate-prod" },
  "storageAccountName": { "type": "String", "value": "sttfstateabc12345" }
}
```

Opcionalmente, verifique o container pelo Azure CLI:

```bash
az storage container list \
  --account-name "sttfstateabc12345" \
  --auth-mode login --output table
```

---

## Passo 5 — (Opcional) Rodar localmente antes do pipeline

Validar na sua máquina antes de abrir um PR encurta o ciclo de feedback:

```bash
cd infra

terraform init \
  -backend-config="resource_group_name=rg-tfstate-prod" \
  -backend-config="storage_account_name=sttfstateabc12345"

terraform fmt -recursive          # formata os .tf
terraform validate                # valida sintaxe e referências
terraform plan -var-file=dev.tfvars   # mostra o que SERÁ criado (não aplica)

cd ..
```

**Saída esperada** do `plan` (resumida):

```text
Plan: 11 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + app_service_default_hostname = (known after apply)
  + resource_group_name          = "rg-iacdemo-dev"
  + storage_account_name          = (known after apply)
  + vm_private_ip                 = (known after apply)
```

> Para autenticar **localmente** com OIDC você precisaria de uma sessão `az login` ativa — o
> provider `azurerm` com `use_oidc = true` também aceita a credencial da Azure CLI no seu terminal.

---

## Passo 6 — Abrir um Pull Request e ver o custo (Infracost)

```bash
git checkout -b feat/ajusta-vm
# ex.: aumente o vm_size em infra/dev.tfvars (Standard_B2s → Standard_D2s_v5)
git commit -am "feat: aumenta o tamanho da VM"
git push -u origin feat/ajusta-vm
```

Abra o PR no GitHub. O pipeline dispara o job **plan**:

1. faz login no Azure via OIDC;
2. roda `fmt -check`, `validate` e `plan`;
3. o **Infracost** calcula o **diff de custo** e posta um **comentário no PR**.

O comentário mostra o custo mensal **antes vs. depois** da sua mudança. Ajuste o SKU e dê
`git push` de novo — o comentário é **atualizado** (graças a `--behavior=update`), não duplicado.

> **Não vê o comentário?** Confira: a Secret `INFRACOST_API_KEY` existe? O workflow tem
> `permissions: pull-requests: write`? (Tem — mas forks com permissões restritas podem precisar
> de ajuste em *Settings → Actions → Workflow permissions*.)

---

## Passo 7 — Fazer merge e aplicar (com aprovação)

Ao fazer **merge na `main`**, o job **apply** dispara — mas, por declarar
`environment: production`, fica **pausado aguardando aprovação**.

1. Vá em **Actions → (a run) → Review deployments**.
2. Marque `production` e clique em **Approve and deploy**.
3. O Terraform aplica a infraestrutura. Acompanhe o log do `terraform apply`.

Ao final, os **outputs** aparecem no log (nome do RG, IP privado da VM, hostname do App Service).

---

## Passo 8 — Conferir o custo no Infracost Cloud (opcional)

Crie uma conta no [Infracost Cloud](https://dashboard.infracost.io/) (camada gratuita) para:

- ver o **custo agregado** entre PRs e ao longo do tempo;
- configurar **guardrails/políticas** — ex.: marcar para revisão qualquer PR que aumente o custo
  acima de um limite, ou exigir aprovação do FinOps.

A CLI já envia os dados usando a mesma `INFRACOST_API_KEY` configurada no Passo 3.

---

## Passo 9 — Destruir o laboratório (evita custo esquecido)

```bash
cd infra
terraform destroy -var-file=dev.tfvars
cd ..
```

O backend de state (criado no Passo 4) é **separado** e sobrevive ao destroy. Se não for
reutilizar, apague-o também:

```bash
az group delete --name rg-tfstate-prod --yes --no-wait
```

E remova a identidade do Entra ID, se quiser limpar tudo:

```bash
az ad app delete --id "$appId"
```

---

## Como customizar

**Trocar a região:** edite `location` em `infra/dev.tfvars` (e no `bootstrap/main.parameters.json`,
se quiser o state em outra região).

**Mudar os SKUs:** ajuste `vm_size` e `app_service_sku` nos `*.tfvars`. O Infracost mostrará o
impacto no custo no próximo PR.

**Adicionar um recurso novo:** crie um módulo em `modules/<novo>/` com o trio
`variables.tf` / `main.tf` / `outputs.tf`, e chame-o em `infra/main.tf`:

```hcl
module "novo" {
  source              = "../modules/novo"
  name_suffix         = local.name_suffix
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}
```

**Adicionar um ambiente (ex.: `staging`):** crie `infra/staging.tfvars`, adicione `"staging"` à
validação em `infra/variables.tf`, e um novo `project` em `infracost/infracost.yml`.

**Apontar o pipeline para outro ambiente:** o workflow usa `VAR_FILE: dev.tfvars` (variável `env`
no topo de `.github/workflows/terraform.yml`). Troque para `prod.tfvars` ou parametrize por branch.

---

## Custo de referência do laboratório

Estimativa (`Standard_B2s` + Storage LRS + App Service `B1`, região Brazil South — **confirme
sempre no Infracost**, os preços mudam e variam por região):

| Recurso | Ordem de grandeza/mês |
| --- | --- |
| VM Linux `Standard_B2s` | ~US$ 30–40 |
| App Service Plan `B1` | ~US$ 13 |
| Storage Account (LRS, vazia) | < US$ 1 |
| VNet / NSG / NIC | sem custo base relevante |
| **Total dev** | **~US$ 45–55/mês** |

O ambiente `prod.tfvars` usa `Standard_D2s_v5` + App Service `P1v3` e custa
significativamente mais — não o aplique sem necessidade.

---

## Solução de problemas

| Sintoma | Causa provável / correção |
| --- | --- |
| `Error: building AzureRM Client: ... OIDC` | O `subject` do federated credential não casa com o repo/branch (Passo 2). Verifique `org/repo` e o gatilho (`ref:refs/heads/main` vs `pull_request`). |
| `AADSTS70021: No matching federated identity record found` | Faltou criar a credencial federada para o gatilho em uso (PR usa `:pull_request`, push usa `:ref:refs/heads/main`). |
| Pipeline não encontra a configuração do backend | Verifique se `resourceGroupName` e `storageAccountName` existem em `bootstrap/main.parameters.json`. |
| `A resource with the ID ... already exists` | Nome de recurso não é único (ex.: `storageAccountName`). Ajuste o parâmetro/`*.tfvars`. |
| `Error acquiring the state lock` | Um `apply` anterior travou o state. Rode `terraform force-unlock <LOCK_ID>` com cuidado. |
| `Backend configuration changed` | Você mudou `-backend-config`. Rode `terraform init -reconfigure`. |
| Infracost não comenta no PR | Falta a Secret `INFRACOST_API_KEY`, ou *Workflow permissions* restritas no fork, ou `pull-requests: write` ausente. |
| `apply` não roda após o merge | Environment `production` sem reviewers, ou o push não foi na `main`. |
| `Insufficient privileges to complete the operation` | Sua conta não tem permissão para criar app/role assignment (precisa de Owner / User Access Administrator). |

---

## FAQ

**Posso usar Azure DevOps em vez de GitHub Actions?** O conceito é o mesmo (Workload Identity
Federation existe nos dois). Você reescreveria só o `.github/workflows/terraform.yml` como um
pipeline YAML do Azure DevOps.

**Por que não criar o backend de state com o próprio Terraform?** Pelo problema do "ovo e
galinha": o state que descreveria o backend teria de morar no backend que ainda não existe. Por
isso o bootstrap é feito com Bicep, que não tem state local. (Detalhes no artigo.)

**O Infracost é open source?** A **CLI é open source (Apache 2.0)**. A **Cloud Pricing API** é um
serviço hospedado (gratuito, exige chave) e o **Infracost Cloud** é um SaaS comercial com camada
gratuita.

**Preciso do Infracost Cloud?** Não para o básico — o comentário de custo no PR funciona só com a
CLI + `INFRACOST_API_KEY`. O Cloud adiciona dashboards e guardrails de time.

---

## Referências

- [Artigo completo (PT-BR)](https://hendersonandrade.github.io/blog/azure-terraform-infracost.pt-br.html) ·
  [English](https://hendersonandrade.github.io/blog/azure-terraform-infracost.html)
- [Terraform — backend azurerm](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
- [Conectar do GitHub ao Azure com OpenID Connect](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect)
- [O que é Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview)
- [Documentação do Infracost](https://www.infracost.io/docs/) ·
  [Infracost GitHub Actions](https://github.com/infracost/actions)
- [FinOps Framework](https://www.finops.org/framework/)

---

## Licença

MIT.
