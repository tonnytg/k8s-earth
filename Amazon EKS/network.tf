# Terraform DOC
# At this file exist all configuration nedded to K8S Network
# This files following AWS Documentaion for terraform
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs

# Amazon EKS networking
# https://docs.aws.amazon.com/eks/latest/userguide/eks-networking.html

# Create a VPC of K8S
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames  = true # by default come disable except default VPC
  enable_dns_support    = true # by default come disable except default VPC
  tags = {
      Name = "myVPC"
  }
}

# Create a Public Subnet for K8S
resource "aws_subnet" "public_subnet_1a" {
    vpc_id = aws_vpc.myvpc.id

    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
    availability_zone = format("%sa", var.aws_region)
    tags = {
        Name = "public"
    }
}