# GISTR — AWS Infrastructure (Terraform)

Infrastructure-as-Code for migrating the **Gistr** application from **Microsoft Azure App Service** to **AWS ECS-on-EC2**, in the **Asia Pacific (Mumbai) `ap-south-1`** region.

Delivered by **Teleglobal International** for **Gistr (NudgeLab)**.

---

## What this deploys

The Gistr apps (originally Azure App Service containers) run on **Amazon ECS backed by EC2** container instances. Each app is an ECS service with its own task definition, fronted by a single **Application Load Balancer** using host-based routing. Configuration/secrets come from **AWS Secrets Manager**; images come from **Amazon ECR** (migrated from Azure ACR).

### Applications

| App | Container Port | Health Path | Azure source |
|-----|----------------|-------------|--------------|
| frontend | 3000 | `/` | dev-digital-garden-client (Next.js) |
| backend | 5000 | `/` | dev-digital-garden-backend (Next.js) |
| ai | 8080 | `/health` | devgistrllm (Python/Uvicorn) |

### Architecture (per environment)

```
                  Internet
                     |
              Internet Gateway
                     |
   ┌─────────── Public subnets ───────────┐
   │        ALB  +  NAT Gateway            │
   └───────────────────────────────────────┘
                     |  (host-based routing)
   ┌────────── Private (app) subnet ───────┐
   │   ECS EC2 container instances         │
   │   ├─ frontend task (:3000)            │
   │   ├─ backend  task (:5000)            │
   │   └─ ai       task (:8080)            │
   │   outbound -> NAT -> Internet         │
   └───────────────────────────────────────┘
   ┌────────── Private (data) subnet ──────┐
   │   isolated (no internet) — reserved   │
   │   for future DB/cache                 │
   └───────────────────────────────────────┘

External (not provisioned here):
  - MongoDB Atlas  (app DB, connection string in Secrets Manager)
  - Azure Redis    (cache, cross-cloud this phase)
  - Amazon S3      (object storage, already in use)
```

- **Compute:** ECS on EC2 (`m6i.large`), Docker, in the private app subnet (egress via NAT).
- **Networking:** 3-tier VPC — public / private-app / private-data.
- **Images:** Amazon ECR (per app), scan-on-push, lifecycle policy, KMS-encrypted.
- **Secrets:** AWS Secrets Manager, injected into containers as env vars.
- **Security:** private instances (no public IP), IMDSv2, SSM Session Manager (no SSH), least-privilege IAM, KMS-encrypted EBS/logs/secrets.
- **Observability:** CloudWatch log group per app + ECS Container Insights.
- **Access to apps:** ALB (HTTP today; HTTPS/ACM added once DNS is delegated).

---

## Repository layout

```
terraform/
├── bootstrap/            # Creates the S3 bucket that stores remote state (run ONCE, first)
├── modules/             # Reusable building blocks
│   ├── vpc/             # VPC, 3-tier subnets, IGW, NAT, route tables
│   ├── security/        # Security groups (ALB, ECS tasks, ECS instances)
│   ├── secrets/         # KMS key + Secrets Manager secrets (one per app)
│   ├── ecr/             # ECR repositories (scan-on-push, lifecycle)
│   └── ecs/             # ECS cluster, capacity provider, ASG, task defs, services, IAM roles
└── envs/
    └── dev/             # Dev environment — wires the modules together
        ├── main.tf          # module composition
        ├── variables.tf     # per-app config (instance type, port, health path, secret keys)
        ├── providers.tf     # AWS provider + default tags
        ├── versions.tf      # Terraform/provider versions + S3 backend
        ├── terraform.tfvars # environment values (region, CIDRs, names) — NO secrets
        └── outputs.tf       # ALB DNS, ECR URLs, cluster name, etc.
```

> **Production** will reuse the same `modules/` with an `envs/prod/` directory (multi-AZ, NAT per AZ, WAF).

---

## Prerequisites

- **Terraform** >= 1.10 (native S3 state locking)
- **AWS CLI** v2, configured for account `992382467806`, region `ap-south-1`
- **Docker** (only for the ACR → ECR image migration, not for `terraform apply`)
- IAM permissions to create VPC, ECS, EC2, ECR, IAM, KMS, Secrets Manager, ELB, CloudWatch

---

## Remote state

State is stored in **S3** (`s3://gistr-terraform-state-992382467806`), versioned + encrypted, with **native S3 state locking** (`use_lockfile = true` — no DynamoDB needed on Terraform >= 1.10). Each environment uses a separate state key (`dev/terraform.tfstate`, `prod/terraform.tfstate`).

**State is never committed to Git** (see `.gitignore`).

---

## How to deploy

### 1. Bootstrap the state bucket (once per account)

```bash
cd bootstrap
terraform init
terraform apply          # creates gistr-terraform-state-992382467806
```

### 2. Deploy an environment (e.g. dev)

```bash
cd ../envs/dev
terraform init           # connects to the S3 backend
terraform plan           # review changes
terraform apply          # create/update resources
terraform output         # ALB DNS name, ECR URLs, etc.
```

### 3. Migrate container images (Azure ACR → Amazon ECR)

Run per app (requires Docker + `az login` + AWS CLI). On Apple Silicon add `--platform linux/amd64`.

```bash
# ECR login (once)
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin 992382467806.dkr.ecr.ap-south-1.amazonaws.com

# Per app: login to ACR, pull by tag, retag to ECR, push
az acr login --name <acr-registry>
docker pull --platform linux/amd64 <acr>/<repo>:<tag>
docker tag  <acr>/<repo>:<tag> 992382467806.dkr.ecr.ap-south-1.amazonaws.com/<ecr-repo>:latest
docker push 992382467806.dkr.ecr.ap-south-1.amazonaws.com/<ecr-repo>:latest
```

### 4. Load application secrets

Application settings are stored in Secrets Manager (`/gistr/<env>/<app>`) as JSON, injected
into containers as env vars. Populate real values out-of-band (never in Git):

```bash
aws secretsmanager put-secret-value --region ap-south-1 \
  --secret-id /gistr/dev/backend \
  --secret-string file://backend.json
```

The keys to inject are listed per app in `envs/dev/variables.tf` (`secret_keys`).

---

## Common operations

```bash
# Service status
aws ecs describe-services --region ap-south-1 --cluster gistr-dev-cluster \
  --services gistr-dev-frontend gistr-dev-backend gistr-dev-ai \
  --query "services[].{Name:serviceName,Running:runningCount,Desired:desiredCount}" --output table

# Tail app logs
aws logs tail /gistr/dev/backend --region ap-south-1 --since 15m

# Force a new deployment (e.g. after pushing a new :latest image)
aws ecs update-service --region ap-south-1 --cluster gistr-dev-cluster \
  --service gistr-dev-ai --force-new-deployment

# Shell into a running task (ECS Exec)
aws ecs execute-command --region ap-south-1 --cluster gistr-dev-cluster \
  --task <task-id> --container <app> --interactive --command "/bin/sh"
```

---

## External dependencies / operational notes

- **MongoDB Atlas** and **Azure Redis** must allowlist the environment's **NAT Gateway public IP**
  (find it in the AWS console or via `aws ec2 describe-nat-gateways`). Apps run but DB/cache
  calls fail until the IP is allowed.
- **DNS** for `digital-garden.nudgepixels.com` and `gistr.so` is on **Cloudflare**. To map
  subdomains + enable HTTPS, add a CNAME → ALB and an **ACM validation CNAME** per subdomain.
  SSL uses **AWS ACM** (free, auto-renewing).
- **Root EBS volume is 30 GB** (Amazon Linux 2023 AMI minimum), not 20 GB.
- The **AI app** requires a cloud-agnostic way to obtain GCP credentials (service-account key)
  rather than Azure Workload Identity federation, to run outside Azure.

---

## Tagging

Every resource is tagged via provider `default_tags`:

```
Project=Gistr, Environment=<env>, ManagedBy=Terraform, Owner=Teleglobal,
CostCenter=gistr-migration, MigratedFrom="Azure App Service",
SourceAzureSubscription="Microsoft Azure Sponsorship", SourceAzureRegion=centralindia
```
Plus per-app: `Application`, `SourceAzureApp`, `SourceAzureSKU`, `SourceAzurePlan`.

---

## Region

All resources are provisioned in **`ap-south-1` (Mumbai)** only.
