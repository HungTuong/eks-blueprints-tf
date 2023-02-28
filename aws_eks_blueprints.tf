#Cluster provisioning.
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.12.2"

  cluster_name = local.name

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # EKS CONTROL PLANE VARIABLES
  cluster_version = local.cluster_version

  # List of map_users
  map_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${local.iam_name}" # The ARN of the IAM user to add.
      username = "opsuser"                                                                            # The user name within Kubernetes to map to the IAM role
      groups   = ["system:masters"]                                                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
    }
  ]

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    #---------------------------------------------------------#
    # Bottlerocket instance type Worker Group
    #---------------------------------------------------------#
    # Checkout this doc https://github.com/bottlerocket-os/bottlerocket for configuring userdata for Launch Templates
    bottlerocket_x86 = {
      # 1> Node Group configuration - Part1
      node_group_name        = "btl-x86-2vcpu-8mem" # Max 40 characters for node group name
      create_launch_template = true                 # false will use the default launch template
      launch_template_os     = "bottlerocket"       # amazonlinux2eks or bottlerocket
      public_ip              = false                # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
      # 2> Node Group scaling configuration
      desired_size = 1
      max_size     = 5
      min_size     = 1

      # 3> Node Group compute configuration
      ami_type       = "BOTTLEROCKET_x86_64"                              # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM, BOTTLEROCKET_ARM_64, BOTTLEROCKET_x86_64
      capacity_type  = "SPOT"                                             # ON_DEMAND or SPOT
      instance_types = ["m5.large", "m4.large", "m6a.large", "m5a.large"] # List of instances to get capacity from multipe pools
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 50
        }
      ]

      # 4> Node Group network configuration
      subnet_type = "private"
      subnet_ids  = [] # Defaults to private subnet-ids used by EKS Controle plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      k8s_taints = [{ key = "spotInstance", value = "true", effect = "NO_SCHEDULE" }]

      k8s_labels = {
        Environment = "dev"
        WorkerType  = "SPOT"
      }
      additional_tags = {
        Name        = "btl-x86-on-demand"
        subnet_type = "private"
      }
    }
  }

  platform_teams = {
    admin = {
      users = [
        data.aws_caller_identity.current.arn
      ]
    }
  }

  application_teams = {
    team-alpha = {
      "labels" = {
        "appName"     = "alpha-team-app",
        "projectName" = "project-alpha",
        "environment" = "dev",
        "domain"      = "example.com",
        "uuid"        = "example.com",
        "billingCode" = "example",
        "branch"      = "example"
      }
      "quota" = {
        "requests.cpu"    = "6000m",
        "requests.memory" = "16Gi",
        "limits.cpu"      = "12000m",
        "limits.memory"   = "24Gi",
        "pods"            = "60",
        "secrets"         = "10",
        "services"        = "10"
      }
      ## Manifests Example: we can specify a directory with kubernetes manifests that can be automatically applied in the team-riker namespace.
      manifests_dir = "./kubernetes/team-alpha"
      users         = [data.aws_caller_identity.current.arn]
    }
  }

  tags = local.tags
}
