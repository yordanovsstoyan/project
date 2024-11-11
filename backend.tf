# Store state file in S3 bucket
terraform {
  backend "s3" {
    bucket                  = "wordpress-3tier-state"
    region                  = "us-east-2"
    key                     = "wordpress-3tier/terraform.tfstate"
  }
}
