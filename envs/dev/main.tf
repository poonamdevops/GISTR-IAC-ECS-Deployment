# ===========================================================================
# Gistr - DEV environment (ap-south-1)  -  ECS-on-EC2
# Wires the modules into the Dev stack:
#   vpc -> secrets(KMS) -> ecr -> security -> alb -> ecs (cluster+EC2+services)
# EC2 container instances + tasks run in the PRIVATE app subnet (via NAT).
# ===========================================================================

locals {
  app_names = keys(var.apps)

  # ECR repo name per app, e.g. gistr-frontend-dev.
  ecr_repo_names = [for a in local.app_names : "gistr-${a}-${var.environment}"]

  # Distinct ports across all apps (for the security group rules).
  app_ports = distinct([for cfg in var.apps : cfg.port])

  # Per-app extra tags carrying Azure source metadata (traceability).
  app_source_tags = {
    for a, cfg in var.apps : a => {
      SourceAzureApp  = cfg.source_azure_app
      SourceAzureSKU  = cfg.source_azure_sku
      SourceAzurePlan = cfg.source_azure_plan
    }
  }

  # Secret keys (JSON keys inside each app's Secrets Manager secret) to inject
  # into the container as env vars. Sourced from the Azure App Service settings,
  # with Azure platform-only vars filtered out.
  secret_keys = {
    frontend = [
      "DECODO_PROXY_URL", "ENVIRONMENT", "PORT", "SENTRY_AUTH_TOKEN", "SENTRY_DSN"
    ]
    backend = [
      "APPLE_APP_CALLBACK_URL", "APPLE_CALLBACK_APP_REDIRECTION_URL",
      "APPLE_CALLBACK_REDIRECTION_URL", "APPLE_CALLBACK_URL", "APPLE_CLIENT_ID",
      "APPLE_KEY_ID", "APPLE_PRIVATE_KEY", "APPLE_TEAM_ID", "APP_NAME",
      "AUTOSEND_API_KEY", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
      "CLOUDFRONT_DOMAIN", "CLOUDFRONT_KEY_PAIR_ID", "CLOUDFRONT_PRIVATE_KEY",
      "COMMON_ACCESS_TOKEN", "COOKIE_SECRET_KEY", "DODO_API_KEY",
      "DODO_WEBHOOK_SECRET", "ENVIRONMENT", "FRONTEND_URL", "GOOGLE_API_KEY",
      "GOOGLE_APP_CALLBACK_URL", "GOOGLE_CALLBACK_APP_REDIRECTION_URL",
      "GOOGLE_CALLBACK_REDIRECTION_URL", "GOOGLE_CALLBACK_URL",
      "GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET", "GOOGLE_SHEETS_WEBHOOK_SECRET",
      "GRAFANA_LOKI_LOG_HOST", "GRAFANA_LOKI_LOG_PASSWORD",
      "GRAFANA_LOKI_LOG_USERNAME", "HTTP_PROXY_URL", "INTERCOM_SECRET_KEY",
      "INTERNAL_EMAILS", "IPINFO_TOKEN", "LOOPS_API_KEY", "MONGO_URI",
      "NODE_ENV", "PI_API_KEY", "PI_API_SECRET", "PI_USER_AGENT", "PORT",
      "POSTHOG_API_KEY", "POSTHOG_HOST", "RAPID_API_KEY", "REDIS_HOST",
      "REDIS_PASSWORD", "REDIS_PORT", "RESOURCE_INTENSIVE_SERVER_API_KEY",
      "REVENUE_CAT_WEBHOOK_AUTH_HEADER", "SELINE_TOKEN", "SENDGRID_API_KEY",
      "SERVER_BASE_URL", "SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET",
      "USER_JWT_EXPIRATION_TIME", "USER_JWT_REFRESH_TOKEN_EXPIRATION_TIME",
      "USER_JWT_REFRESH_TOKEN_SECRET", "USER_JWT_SECRET", "WEB_SCRAPE_LAMBDA_TOKEN"
    ]
    ai = [
      "ACCESS_KEY_AWS", "ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL", "API_KEY",
      "AUDIO_ACCESS_API_KEY", "AWS_ACCESS_KEY", "AWS_BUCKET_NAME",
      "AWS_REGION_NAME", "AZURE_ACCESS_TOKEN", "AZURE_OPENAI_API_KEY",
      "AZURE_OPENAI_ENDPOINT", "BACKEND_URL", "BACKGROUND_API_KEY",
      "DAILY_CREDIT_LIMIT", "DBDEV_NAME", "DBDEV_URI", "DBPRODUCTION_NAME",
      "DBPRODUCTION_URI", "DECODO_PASSWORD", "DECODO_USERNAME", "ELEVENLABS_KEY",
      "ENV_TYPE", "EXPLORE_PAGE_ACCESS_API_KEY", "GAMMA_API_BASE_URL",
      "GAMMA_API_KEY", "GITHUB_TOKEN", "GOOGLE_API_KEY",
      "GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_CLOUD_PROJECT",
      "GOOGLE_CREDENTIALS", "GOOGLE_CSE_ID", "GOOGLE_PROJECT_ID",
      "GOOGLE_PROJECT_NUMBER", "GOOGLE_SEARCH_API_KEY",
      "GOOGLE_SHEETS_CREDENTIALS", "GOOGLE_WORKLOAD_POOL",
      "GOOGLE_WORKLOAD_PROVIDER", "GROQ_API_KEY", "INTERNAL_API_KEY",
      "LANGCHAIN_API_KEY", "LANGCHAIN_ENDPOINT", "LANGCHAIN_PROJECT",
      "LANGCHAIN_TRACING_V2", "LANGFUSE_PUBLIC_KEY", "LANGFUSE_SECRET_KEY",
      "LANGFUSE_TRACING_ENVIRONMENT", "LANGSMITH_API_KEY", "LANGSMITH_TRACING",
      "LANGUSE_HOST", "MONGO_DB_NAME", "MONGO_DB_URI", "OPEN_AI_API_KEY",
      "OPEN_ROUTER_API_KEY", "OPEN_ROUTER_BASE_URL", "PAID_GOOGLE_API_KEY",
      "POSTHOG_API_KEY", "PPTX_CONVERTER_PROVIDER", "PPTX_CONVERTER_URL",
      "PYTEST_TESTING_ENV", "RAPID_API_KEY", "RAPID_HOST_KEY",
      "SECRET_ACCESS_KEY", "SERVICE_ACCOUNT_EMAIL", "SHEET_ID", "TAVILY_API_KEY",
      "TF_ENABLE_ONEDNN_OPTS", "USER_JWT_SECRET"
    ]
  }
}

# ---- Network --------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name_prefix                  = var.name_prefix
  vpc_cidr                     = var.vpc_cidr
  public_subnet_cidr           = var.public_subnet_cidr
  public_subnet_secondary_cidr = var.public_subnet_secondary_cidr
  private_app_subnet_cidr      = var.private_app_subnet_cidr
  private_data_subnet_cidr     = var.private_data_subnet_cidr
}

# ---- KMS + Secrets Manager (placeholders) ---------------------------------
module "secrets" {
  source = "../../modules/secrets"

  name_prefix = var.name_prefix
  environment = var.environment
  app_names   = local.app_names
}

# ---- ECR repositories -----------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  repository_names = local.ecr_repo_names
  kms_key_arn      = module.secrets.kms_key_arn
  force_delete     = true # Dev convenience
}

# ---- Security groups (ALB + ECS tasks + ECS instances) --------------------
module "security" {
  source = "../../modules/security"

  name_prefix = var.name_prefix
  vpc_id      = module.vpc.vpc_id
  app_ports   = local.app_ports
}

# ---- ALB (target groups by IP for awsvpc ECS tasks) -----------------------
module "alb" {
  source = "../../modules/alb"

  name_prefix       = var.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  default_app       = var.default_app
  enable_https      = var.enable_https

  apps = {
    for a, cfg in var.apps : a => {
      port              = cfg.port
      hostname          = cfg.hostname
      health_check_path = cfg.health_check_path
    }
  }
}

# ---- ECS on EC2 (cluster, capacity, task defs, services) ------------------
module "ecs" {
  source = "../../modules/ecs"

  name_prefix = var.name_prefix
  environment = var.environment
  aws_region  = var.aws_region

  # EC2 container instances + tasks in the private app subnet (outbound via NAT).
  instance_type       = var.ecs_instance_type
  private_subnet_ids  = [module.vpc.private_app_subnet_id]
  root_volume_size_gb = 30

  ecs_instances_sg_id = module.security.ecs_instances_sg_id
  ecs_tasks_sg_id     = module.security.ecs_tasks_sg_id

  kms_key_arn        = module.secrets.kms_key_arn
  secret_arns        = module.secrets.secret_arns
  secret_arns_by_app = module.secrets.secret_arns_by_app

  target_group_arns = module.alb.target_group_arns

  # One task def + service per app. Image starts at :latest (pushed via ACR->ECR
  # migration / CICD). CPU/memory sized to fit the m6i.large (2 vCPU / 8 GB).
  apps = {
    for a, cfg in var.apps : a => {
      image_url   = module.ecr.repository_urls["gistr-${a}-${var.environment}"]
      image_tag   = "latest"
      port        = cfg.port
      cpu         = var.task_cpu
      memory      = var.task_memory
      secret_keys = lookup(local.secret_keys, a, [])
    }
  }
}
