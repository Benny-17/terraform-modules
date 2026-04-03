# AWS Infrastructure with Terraform

Production-ready AWS infrastructure using Terraform Infrastructure as Code.

## Architecture
```
Internet → ALB → EKS Cluster → RDS Database
```

**Components:**
- VPC: Networking with public/private subnets
- EKS: Kubernetes cluster with worker nodes
- RDS: PostgreSQL database
- ALB: Application load balancer

## Quick Start

### Prerequisites
```bash
terraform 
aws-cli
kubectl
```

### Deploy
```bash
cd terraform

terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
# Wait 10-15 minutes
```

### Get Outputs
```bash
terraform output
# alb_dns_name = xxx.ap-south-1.elb.amazonaws.com
# rds_endpoint = xxx.rds.amazonaws.com:5432
```

### Configure kubectl
```bash
aws eks update-kubeconfig --name test-eks-dev --region ap-south-1
kubectl get nodes
```

## Project Structure
```
terraform/
├── main.tf              # Calls all modules
├── variables.tf         # Variables
├── outputs.tf          # Outputs
├── backend.tf          # Remote state (S3)
├── dev.tfvars          # Dev config
└── modules/
    ├── vpc/            # Networking
    ├── eks/            # Kubernetes
    ├── rds/            # Database
    └── alb/            # Load balancer
```

## Configuration

Edit `dev.tfvars`:
```hcl
rds_username = "postgres"
rds_password = "YourPassword123!"
```

## Cost

~$150/month (within free tier)

## Issues Faced & Solutions

| Issue | Solution |
|-------|----------|
| Circular dependency in security groups | Used separate `aws_security_group_rule` resources |
| State lock stuck in DynamoDB | Deleted lock with AWS CLI |
| VPC CNI addon timeout | Increased timeout to 30 minutes |
| PostgreSQL version not found | Changed to version "15" |
| Reserved username "admin" | Changed to "postgres" |

## Commands
```bash
# Plan
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"

# Destroy
terraform destroy -var-file="dev.tfvars"

# Outputs
terraform output

# Verify cluster
kubectl get nodes
```

## Security

- Private subnets (EKS & RDS not internet-exposed)
- Security groups restrict all traffic
- Only ALB is public
- Encrypted backups
- Remote state with DynamoDB locking

## Technologies

Terraform | AWS | EKS | RDS | PostgreSQL | Kubernetes

## License

MIT
