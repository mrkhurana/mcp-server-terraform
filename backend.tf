terraform {
  backend "s3" {
    bucket  = "tf-state-backup-kay-bkp"
    key     = "aiops-mcp/runtime/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
