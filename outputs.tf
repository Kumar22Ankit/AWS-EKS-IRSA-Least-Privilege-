output "cluster_name" {
  value = module.eks.cluster_name
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "irsa_role_arn" {
  value = module.irsa.iam_role_arn
}

output "region" {
  value = var.region
}
