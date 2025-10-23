# Get cluster details (for OIDC)
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

# Create IAM policy for S3 ReadOnly
resource "aws_iam_policy" "s3_readonly" {
  name        = "S3ReadOnlyPolicyForIRSA"
  description = "Allow read access to demo bucket"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::irsa-least-privilege-demo-bucket",
          "arn:aws:s3:::irsa-least-privilege-demo-bucket/*"
        ]
      }
    ]
  })
}

module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "irsa-s3-reader"

  role_policy_arns = {
    s3_readonly = aws_iam_policy.s3_readonly.arn
  }

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:s3-reader"]
    }
  }
}
