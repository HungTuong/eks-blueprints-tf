variable "fe_secrets" {
  description = "Secrets for fe"
  type        = map(string)
}

variable "be_secrets" {
  description = "Secrets for be"
  type        = map(string)
}


variable "acm_arn" {
  description = "ACM arn for api domain"
  type        = string
}
