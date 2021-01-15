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

# Message to help build EKS
variable "eks_command" {
  type    = string
  default = "eksctl create cluster --name myCluster --version 1.18 --region us-east-1 --managed --nodes 2 --nodes-min 1 --nodes-max 3 --vpc-private-subnets=<SUBNET PRIVATE ID 1>,<SUBNET PRIVATE ID 1> --vpc-public-subnets=<SUBNET PUBLIC ID 1>,<SUBNET PUBLIC ID 2>"
}

