# AWS Region
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# EKS Cluster
variable "cluster_name" {
  type    = string
  default = "myEKS"
}