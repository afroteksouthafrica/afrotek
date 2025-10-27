variable "project" {
  type    = string
  default = "afrotek"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "auth_image" {
  type    = string
  default = "166023635884.dkr.ecr.af-south-1.amazonaws.com/afrotek/auth:latest"
}

variable "product_image" {
  type    = string
  default = "166023635884.dkr.ecr.af-south-1.amazonaws.com/afrotek-product-service:temp-health-2"
}
