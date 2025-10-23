module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  
  cluster_endpoint_public_access = true
  
  
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] 
  
  tags = {
    Project = "IRSA-Demo"
    Owner   = "Ankit"
    Purpose = "Blog-Lab"
  }

  eks_managed_node_groups = {
    demo = {
      desired_capacity = 1
      max_capacity     = 1
      min_capacity     = 1
      instance_types   = ["t3.micro"]
    }
  }
}