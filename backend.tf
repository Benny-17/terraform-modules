# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-123456789012"  # Replace with your account ID
    key            = "terraform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}