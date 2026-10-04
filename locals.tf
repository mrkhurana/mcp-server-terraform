locals {
  name             = "${var.project_name}-${var.environment}"
  eks_cluster_name = var.eks_cluster_name != "" ? var.eks_cluster_name : "${var.project_name}-${var.environment}"

  tags = merge(
    {
      Name        = local.name
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}
