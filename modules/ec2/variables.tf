variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the test EC2 instance should be launched."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet where the EC2 test instance will live."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR used for private egress rules."
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group used for access to the internal MCP endpoint."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the test host."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Optional custom AMI override. Defaults to the latest Amazon Linux 2023 AMI."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to the EC2 test instance and related resources."
  type        = map(string)
  default     = {}
}
