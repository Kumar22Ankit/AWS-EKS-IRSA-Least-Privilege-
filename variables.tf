variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "irsa-least-privilege-demo"
}

variable "vpc_id" {
  description = "Existing VPC ID (use default VPC)"
  default     = "vpc-0662e67d56cc1b662"
}

variable "subnet_ids" {
  description = "Subnets for EKS nodes"
  type        = list(string)
  default     = ["subnet-0dd44f5053a7549d6", "subnet-04112ff11b298ace8"] 
}
