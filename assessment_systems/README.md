# AKS Assessment – Infrastructure & Application Deployment

A production-grade reference implementation demonstrating:

- **Infrastructure as Code** with modular Terraform (AKS · ACR · Key Vault · Monitoring)
- **Containerised application** with multi-stage Docker build
- **Kubernetes manifests** with HA, autoscaling, and Key Vault secret injection
- **CI/CD pipeline** using GitHub Actions with OIDC authentication (no static secrets)

---

## Repository Structure

```
.
├── terraform/
│   ├── versions.tf              # Provider versions & backend config
│   ├── main.tf                  # Root module – VNet, resource group, module calls
│   ├── variables.tf             # Input variable definitions
│   ├── outputs.tf               # Key outputs (cluster name, ACR URL, etc.)
│   ├── terraform.tfvars.example # Sample variable values
│   └── modules/
│       ├── aks/                 # AKS cluster, node pools, RBAC
│       ├── acr/                 # Azure Container Registry
│       ├── keyvault/            # Key Vault + RBAC + seed secrets
│       └── monitoring/          # Log Analytics, Managed Prometheus, Grafana
├── app/
│   ├── app.py                   # Flask API (health · ready · secret endpoints)
│   ├── requirements.txt
│   └── Dockerfile               # Multi-stage build (builder + slim runtime)
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 01-secret-provider-class.yaml   # Key Vault CSI Driver binding
│   ├── 02-deployment.yaml              # 2-replica deployment, rolling update
│   ├── 03-service.yaml                 # ClusterIP service
│   ├── 04-pdb.yaml                     # PodDisruptionBudget (minAvailable: 1)
│   ├── 05-hpa.yaml                     # HPA (2–10 replicas, CPU/memory)
│   └── 06-ingress.yaml                 # NGINX Ingress (external access)
└── .github/
    └── workflows/
        └── ci-cd.yml            # Build → push → deploy pipeline
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    Azure Subscription                │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │           Resource Group: rg-aksassess-dev   │   │
│  │                                              │   │
│  │  ┌─────────┐  ┌──────────┐  ┌────────────┐  │   │
│  │  │   ACR   │  │ Key Vault│  │  Grafana   │  │   │
│  │  └────┬────┘  └────┬─────┘  └─────┬──────┘  │   │
│  │       │            │ CSI          │          │   │
│  │  ┌────▼────────────▼──────────────▼───────┐  │   │
│  │  │              AKS Cluster               │  │   │
│  │  │  ┌──────────┐    ┌──────────────────┐  │  │   │
│  │  │  │  System  │    │   User Node Pool │  │  │   │
│  │  │  │ Node Pool│    │  (auto-scale 1–5)│  │  │   │
│  │  │  └──────────┘    └────────┬─────────┘  │  │   │
│  │  │                           │             │  │   │
│  │  │          ┌────────────────▼──────────┐  │  │   │
│  │  │          │   assessment namespace    │  │  │   │
│  │  │          │  Deployment (2–10 pods)   │  │  │   │
│  │  │          │  Service · HPA · PDB      │  │  │   │
│  │  │          └────────────────┬──────────┘  │  │   │
│  │  │                           │             │  │   │
│  │  │          ┌────────────────▼──────────┐  │  │   │
│  │  │          │    NGINX Ingress (LB IP)  │  │  │   │
│  │  │          └────────────────┬──────────┘  │  │   │
│  │  └───────────────────────────│─────────────┘  │   │
│  └──────────────────────────────│─────────────────┘  │
└─────────────────────────────────│─────────────────────┘
                                  │
                             Internet 🌐
```

---

## Prerequisites

| Tool            | Minimum Version | Install                          |
|-----------------|-----------------|----------------------------------|
| Terraform       | 1.5.0           | https://developer.hashicorp.com/terraform/install |
| Azure CLI       | 2.60.0          | https://docs.microsoft.com/cli/azure/install      |
| kubectl         | 1.29            | https://kubernetes.io/docs/tasks/tools/           |
| Helm            | 3.14            | https://helm.sh/docs/intro/install/               |
| Docker          | 25+             | https://docs.docker.com/get-docker/               |

---

## Quick Start

### 1 · Azure Login

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### 2 · Provision Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan  -out tfplan
terraform apply tfplan
```

Key outputs printed after apply:

```
kubeconfig_command    = "az aks get-credentials --resource-group rg-aksassess-dev ..."
acr_login_server      = "acraksassessdevXXXXXX.azurecr.io"
key_vault_uri         = "https://kv-aksassess-dev-XXXXXX.vault.azure.net/"
```

### 3 · Configure kubectl

```bash
$(terraform output -raw kubeconfig_command)
kubectl get nodes
```

### 4 · Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux
```

### 5 · Update Manifest Placeholders

Edit `k8s/01-secret-provider-class.yaml`:
```yaml
keyvaultName: "<KEYVAULT_NAME>"   # terraform output key_vault_name
tenantId:     "<TENANT_ID>"       # terraform output tenant_id
```

Edit `k8s/02-deployment.yaml`:
```yaml
image: <ACR_LOGIN_SERVER>/assessment-app:latest
```

### 6 · Apply Kubernetes Manifests

```bash
kubectl apply -f k8s/
kubectl rollout status deployment/assessment-app -n assessment
```

### 7 · Verify External Access

```bash
kubectl get ingress -n assessment
# Note EXTERNAL-IP, then:
curl http://<EXTERNAL-IP>/health
curl http://<EXTERNAL-IP>/
```

---

## CI/CD Pipeline

The GitHub Actions workflow (`ci-cd.yml`) uses **OIDC federated identity** — no long-lived credentials stored as secrets.

### Required GitHub Secrets

| Secret                 | Description                              |
|------------------------|------------------------------------------|
| `AZURE_CLIENT_ID`      | App Registration / Managed Identity ID  |
| `AZURE_TENANT_ID`      | Azure AD tenant ID                       |
| `AZURE_SUBSCRIPTION_ID`| Target Azure subscription                |
| `ACR_LOGIN_SERVER`     | e.g. `acraksassessdevXXX.azurecr.io`    |
| `AKS_CLUSTER_NAME`     | e.g. `aks-aksassess-dev`                 |
| `AKS_RESOURCE_GROUP`   | e.g. `rg-aksassess-dev`                  |

### Pipeline Stages

```
Push to branch
      │
      ▼
┌─────────────────────────────────────┐
│  CI Job                             │
│  lint → test → docker build → push │
│  → Trivy vulnerability scan         │
└─────────────────┬───────────────────┘
                  │ main branch only
                  ▼
┌─────────────────────────────────────┐
│  Deploy Dev                         │
│  kubectl apply + rollout + smoke    │
└─────────────────┬───────────────────┘
                  │ semver tag (v*.*.*)
                  ▼
┌─────────────────────────────────────┐
│  Deploy Prod  (manual approval)     │
│  kubectl apply + rollout            │
└─────────────────────────────────────┘
```

---

## High Availability Strategy

| Mechanism                  | What it provides                                    |
|----------------------------|-----------------------------------------------------|
| `replicas: 2` minimum      | No single point of failure at pod level             |
| `HPA` (2–10 replicas)      | Auto-scale under load                               |
| `topologySpreadConstraints`| Pods spread across different nodes                  |
| `PodDisruptionBudget`      | At least 1 pod survives voluntary disruptions       |
| `RollingUpdate` strategy   | Zero-downtime deployments (`maxUnavailable: 0`)     |
| `User node pool` auto-scale| Cluster scales out under sustained load (1–5 nodes) |
| NGINX Ingress (2 replicas) | Redundant ingress layer                             |

---

## Security Highlights

- **No admin credentials** in Docker image or Kubernetes manifests
- Secrets injected at runtime via **Azure Key Vault CSI Driver**; also synced as Kubernetes Secrets for `envFrom`
- **OIDC Workload Identity** eliminates static credentials in CI/CD
- **Non-root container** (`runAsUser: 10001`, `allowPrivilegeEscalation: false`)
- **Read-only root filesystem** with explicit `emptyDir` for `/tmp`
- **Network Policy** enforced via Calico
- **ACR admin disabled**; image pull via kubelet managed identity + `AcrPull` role

---

## Monitoring & Observability

| Component              | Purpose                                             |
|------------------------|-----------------------------------------------------|
| Container Insights     | Pod/node metrics, logs in Log Analytics             |
| Managed Prometheus     | Kubernetes and app-level metrics scraping           |
| Grafana                | Pre-built AKS dashboards linked to Azure Monitor    |

Access Grafana:
```bash
terraform output grafana_endpoint   # or: module.monitoring.grafana_endpoint
```

---

## Teardown

```bash
# Remove Kubernetes resources
kubectl delete -f k8s/

# Destroy all Azure resources
cd terraform
terraform destroy
```

---

## Design Decisions

| Decision                        | Rationale                                                   |
|---------------------------------|-------------------------------------------------------------|
| Modular Terraform               | Each module can be versioned, tested, and reused independently |
| Azure CNI over kubenet           | Required for advanced network policies and AKS features     |
| System / user node pool split    | Critical add-ons isolated from application workloads        |
| OIDC instead of Service Principal secrets | No credential rotation; shorter-lived tokens         |
| Gunicorn over Flask dev server   | Production-grade WSGI server; handles concurrent requests   |
| Multi-stage Docker build         | Final image contains no build tools; reduces attack surface |
