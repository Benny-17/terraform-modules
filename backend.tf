# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "terraformstatefile-testbucket01"  # Replace with your account ID
    key            = "terraform/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}