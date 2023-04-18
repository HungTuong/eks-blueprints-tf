# Find the user currently in use by AWS
data "aws_caller_identity" "current" {}

# Region in which to deploy the solution
data "aws_region" "current" {}

# Availability zones to use in our solution
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_kms_key" "key" {
  key_id = "752b8f4f-b1b8-48b3-a981-603e90d2411c"
}

data "aws_s3_bucket" "taly_video" {
  bucket = var.be_secrets.AWS_BUCKET_NAME
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_cloudfront_distribution" "frontend" {
  id = "E3THX1BMLK2B2Y"
}

data "aws_route53_zone" "domain" {
  name = local.domain
}
