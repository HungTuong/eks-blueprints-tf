locals {
  project         = "thesis"
  iam_name        = "hungt.iam"
  region          = data.aws_region.current.name
  cluster_version = "1.24"
  namespace       = "default"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  #---------------------------------------------------------------
  # ADD-ON APPLICATION
  #---------------------------------------------------------------

  # External secrets
  cluster_secretstore_name = "secrets-store-csi"
  cluster_secretstore_sa   = "secrets-store-csi-sa"
  secretstore_name         = "secretstore-ps"
  secretstore_sa           = "secretstore-sa"
  addon_application = {
    path               = "chart"
    repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
    add_on_application = true
  }

  tags = {
    Terraform   = "True"
    Environment = "dev"
  }
}
