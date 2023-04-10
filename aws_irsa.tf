#---------------------------------------------------------------
# AWS Secret
#---------------------------------------------------------------
resource "aws_secretsmanager_secret" "fe_secrets" {
  name                    = "TALY_FE_ENV"
  description             = "Environment secrets for application front end"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret" "be_secrets" {
  name                    = "TALY_BE_ENV"
  description             = "Environment secrets for application back end"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "fe" {
  secret_id = aws_secretsmanager_secret.fe_secrets.id
  secret_string = jsonencode({
    NEXT_PUBLIC_API_URL               = var.fe_secrets.NEXT_PUBLIC_API_URL,
    NEXT_PUBLIC_GOOGLE_AUTH_CLIENT_ID = var.fe_secrets.NEXT_PUBLIC_GOOGLE_AUTH_CLIENT_ID
  })
}

resource "aws_secretsmanager_secret_version" "be" {
  secret_id = aws_secretsmanager_secret.be_secrets.id
  secret_string = jsonencode({
    PORT                  = var.be_secrets.PORT,
    MONGO_URL             = var.be_secrets.MONGO_URL,
    GOOGLE_AUTH_CLIENT_ID = var.be_secrets.GOOGLE_AUTH_CLIENT_ID,
    ADMIN_EMAIL           = var.be_secrets.ADMIN_EMAIL,
    JWT_SECRET            = var.be_secrets.JWT_SECRET,
    FE_URL                = var.be_secrets.FE_URL,
    BE_URL                = var.be_secrets.BE_URL,
    ADMIN_SESSION_SECRET  = var.be_secrets.ADMIN_SESSION_SECRET,
    SENDGRID_API_KEY      = var.be_secrets.SENDGRID_API_KEY,
    SENDGRID_FROM         = var.be_secrets.SENDGRID_FROM,
    AWS_REGION            = var.be_secrets.AWS_REGION,
    AWS_BUCKET_NAME       = var.be_secrets.AWS_BUCKET_NAME
  })
}

#---------------------------------------------------------------
# S3 Bucket
#---------------------------------------------------------------

resource "aws_s3_bucket_policy" "s3_vpce_policy" {
  bucket = var.be_secrets.AWS_BUCKET_NAME
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "${data.aws_s3_bucket.taly_video.arn}/*",
        "${data.aws_s3_bucket.taly_video.arn}"
      ],
      "Effect": "Allow",
      "Condition": {
        "StringEquals": {
          "aws:sourceVpce": "${module.endpoints.endpoints.s3.id}"
        }
      }
    }
  ]
}
POLICY
}

#---------------------------------------------------------------
# IRSA
#---------------------------------------------------------------

module "cluster_role" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints-addons/modules/irsa"

  kubernetes_namespace        = local.namespace
  create_kubernetes_namespace = false
  kubernetes_service_account  = local.cluster_sa
  irsa_iam_policies = [
    aws_iam_policy.cluster_secretstore.arn,
    aws_iam_policy.cluster_s3.arn
  ]
  eks_cluster_id        = module.eks_blueprints.eks_cluster_id
  eks_oidc_provider_arn = module.eks_blueprints.eks_oidc_provider_arn

  depends_on = [
    module.eks_blueprints_kubernetes_addons
  ]
}

resource "aws_iam_policy" "cluster_secretstore" {
  name_prefix = local.cluster_secretstore_sa
  policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ],
    "Resource": [
      "${aws_secretsmanager_secret.fe_secrets.arn}",
      "${aws_secretsmanager_secret.be_secrets.arn}"
    ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:key/*"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "cluster_s3" {
  name_prefix = local.cluster_s3_sa
  policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject"
    ],
    "Resource": [
      "${data.aws_s3_bucket.taly_video.arn}/*",
      "${data.aws_s3_bucket.taly_video.arn}"
    ]
    }
  ]
}
POLICY
}
