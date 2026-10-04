output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "fargate_profile_name" {
  value = aws_eks_fargate_profile.this.fargate_profile_name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.cluster.name
}

output "cluster_role_arn" {
  value = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "EKS Fargate pod execution role ARN used to run workloads in the application namespace."
  value       = aws_iam_role.fargate.arn
}
