# module "ecr" {
#   source = "terraform-aws-modules/ecr/aws"

#   repository_name = "private-repo"

#   repository_lifecycle_policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1,
#         description  = "Keep last 10 images",
#         selection = {
#           tagStatus     = "tagged",
#           tagPrefixList = ["v"],
#           countType     = "imageCountMoreThan",
#           countNumber   = 10
#         },
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })

#   tags = local.tags
# }
