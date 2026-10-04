variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region used to construct VPC endpoint service names."
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name used for subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the workshop VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones for the private subnets. Empty selects the first two available zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for the EKS nodes, ECS tasks, and VPC endpoints."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for the internet-facing ALB."
  type        = list(string)
  default     = ["10.20.21.0/24", "10.20.22.0/24"]
}

variable "enable_vpc_endpoints" {
  description = "Create the interface and S3 gateway endpoints required for private ECR image pulls, EKS node networking, and CloudWatch logging."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
