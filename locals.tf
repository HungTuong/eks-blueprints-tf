locals {
  project         = "thesis"
  iam_name        = "hungt.iam"
  region          = data.aws_region.current.name
  cluster_version = "1.25"
  namespace       = "default"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  #---------------------------------------------------------------
  # ADD-ON APPLICATION
  #---------------------------------------------------------------

  cluster_s3_sa          = "s3-sa"
  cluster_secretstore_sa = "secrets-store-csi-sa"
  cluster_sa             = "cluster-sa"
  addon_application = {
    path               = "chart"
    repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
    add_on_application = true
  }


  waf = {
    # the priority in waf will be referenced to the order of the rules in the list
    managed_rules = [
      "AWSManagedRulesCommonRuleSet",
      "AWSManagedRulesLinuxRuleSet",
      "AWSManagedRulesKnownBadInputsRuleSet",
      "AWSManagedRulesAmazonIpReputationList",
      "AWSManagedRulesAnonymousIpList",
      "AWSManagedRulesAdminProtectionRuleSet"
    ]
  }
  tags = {
    Terraform   = "True"
    Environment = "dev"
  }
}
