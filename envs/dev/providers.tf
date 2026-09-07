# AWS provider. default_tags applies these tags to EVERY taggable resource.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project                 = "Gistr"
      Environment             = var.environment
      ManagedBy               = "Terraform"
      Owner                   = var.owner
      CostCenter              = var.cost_center
      MigratedFrom            = "Azure App Service"
      SourceAzureSubscription = "Microsoft Azure Sponsorship"
      SourceAzureRegion       = "centralindia"
      SourceAzureRG           = "development-gistr-group"
    }
  }
}
