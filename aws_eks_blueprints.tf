#Cluster provisioning.
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.27.0"

  cluster_name = local.project

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # EKS CONTROL PLANE VARIABLES
  cluster_version     = local.cluster_version
  cluster_kms_key_arn = data.aws_kms_key.key.arn

  # List of map_users
  map_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${local.iam_name}" # The ARN of the IAM user to add.
      username = "opsuser"                                                                            # The user name within Kubernetes to map to the IAM role
      groups   = ["system:masters"]                                                                   # A list of groups within Kubernetes to which the role is mapped; Checkout K8s Role and Rolebindings
    }
  ]

  # EKS MANAGED NODE GROUPS
  node_security_group_additional_rules = {
    ingress_self_front_end = {
      description = "Allow FE access within node groups"
      protocol    = "tcp"
      from_port   = 8000
      to_port     = 8000
      type        = "ingress"
      self        = true
    }

    ingress_self_back_end = {
      description = "Allow BE access within node groups"
      protocol    = "tcp"
      from_port   = 5000
      to_port     = 5000
      type        = "ingress"
      self        = true
    }

    egress_to_mongodb = {
      description = "Node to mongoDB"
      protocol    = "tcp"
      from_port   = 27017
      to_port     = 27017
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller."
    }
  }

  managed_node_groups = {
    #---------------------------------------------------------#
    # Bottlerocket instance type Worker Group
    #---------------------------------------------------------#
    # Checkout this doc https://github.com/bottlerocket-os/bottlerocket for configuring userdata for Launch Templates
    bottlerocket_x86 = {
      # 1> Node Group configuration - Part1
      node_group_name        = "btl-x86"      # Max 40 characters for node group name
      create_launch_template = true           # false will use the default launch template
      launch_template_os     = "bottlerocket" # amazonlinux2eks or bottlerocket
      public_ip              = false          # Use this to enable public IP for EC2 instances; only for public subnets used in launch templates ;
      # 2> Node Group scaling configuration
      desired_size = 1
      max_size     = 2
      min_size     = 1

      # 3> Node Group IAM policy configuration
      iam_role_additional_policies = {
        "ManagedEcr" : "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "ManagedSecrets" : "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
      }

      # 4> Node Group compute configuration
      ami_type       = "BOTTLEROCKET_x86_64"                              # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM, BOTTLEROCKET_ARM_64, BOTTLEROCKET_x86_64
      capacity_type  = "SPOT"                                             # ON_DEMAND or SPOT
      instance_types = ["m5.large", "m4.large", "m6a.large", "m5a.large"] # List of instances to get capacity from multipe pools
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 20
        }
      ]

      # 5> Node Group network configuration
      subnet_type = "private"
      subnet_ids  = module.vpc.private_subnets # Defaults to private subnet-ids used by EKS Controle plane. Define your private/public subnets list with comma separated subnet_ids  = ['subnet1','subnet2','subnet3']

      k8s_labels = {
        Environment = "dev"
        WorkerType  = "SPOT"
      }
      additional_tags = {
        Name        = "btl-x86-spot"
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

  tags = local.tags
}
