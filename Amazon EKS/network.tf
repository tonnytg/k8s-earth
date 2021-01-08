###
#   Hello friend, this manifest will help you to build a EKS network with Terraform,
#   but you dont't need this terraform because command eksctl build everything with one command :D
#   this terraform can help you when you can't use eksctl just like at this cases.
###

# Terraform DOC
# At this file exist all configuration nedded to K8S Network
# This files following AWS Documentaion for terraform
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs

# Amazon EKS networking
# https://docs.aws.amazon.com/eks/latest/userguide/eks-networking.html

###
# Resume of this file
###
# Create a VPC, with 2 public subnet and 2 private subnet
# Create a Elastic IP, Internet Gateway and Nat Gateway
# This is a basic Network infrasestructure to create a EKS
# After running this terraformation you need execute command eksclt
#
# After build VPC and Subnets
# This command build EKS Cluster with 2 Subnets private and 2 Subnets public
# https://eksctl.io/usage/vpc-networking/
# eksctl create cluster --name myCluster --version 1.18 \
# --region us-east-1 --managed --nodes 2 --nodes-min 1 --nodes-max 3 \
# --vpc-private-subnets=subnet-01c79b7b090b5199c,subnet-0f6efb0ee6d338ea6 \
# --vpc-public-subnets=subnet-0063e09cc658b0943,subnet-0dc1380dc72a626a2
#
####

###
#   Cost
#   https://aws.amazon.com/ec2/pricing/on-demand/
###
#   2 instances = m5.large 0,096 USD    x 2 = 0,192/hour x 24 hours = $4/day
#   NAT Gateway = 0,045 USD/hours       x 24 hours                  = $1,08/day
#   
#   Total Cost  = 0,141/hour USD                                    = $5,08/day
###

# Create a VPC of K8S
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames  = true # by default come disable except default VPC
  enable_dns_support    = true # by default come true
  tags = {
      Name = format("%s-vpc",var.cluster_name)
  }
}

####
# Public Subnet
###
# Create a Public Subnet A for K8S
resource "aws_subnet" "eks_subnet_public_1a" {
    vpc_id = aws_vpc.eks_vpc.id

    cidr_block = "10.0.10.0/24"
    map_public_ip_on_launch = true
    availability_zone = format("%sa", var.aws_region)

    # TAG alert
    # https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#vpc-subnet-tagging
    tags = {
        Name = format("%s-eks_subnet_public_1a", var.cluster_name)
        "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
}

# Create a Public Subnet B for K8S
resource "aws_subnet" "eks_subnet_public_1b" {
    vpc_id = aws_vpc.eks_vpc.id

    cidr_block = "10.0.11.0/24"
    map_public_ip_on_launch = true
    availability_zone = format("%sb", var.aws_region)

    # TAG alert
    # https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#vpc-subnet-tagging
    tags = {
        Name = format("%s-eks_subnet_public_1b", var.cluster_name)
        "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
}

# Edit Route Table of Subnet Public A
resource "aws_route_table_association" "eks_public_rt_association_1a" {
  subnet_id      = aws_subnet.eks_subnet_public_1a.id
  route_table_id = aws_route_table.eks_public_rt.id # Link with Internet Gateway
}

# Edit Route Table of Subnet Public B
resource "aws_route_table_association" "eks_public_rt_association_1b" {
  subnet_id      = aws_subnet.eks_subnet_public_1b.id
  route_table_id = aws_route_table.eks_public_rt.id # Link with Internet Gateway
}

####
# Private Subnet
###
# Create a Private Subnet A for K8S
resource "aws_subnet" "eks_subnet_private_1a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = format("%sa", var.aws_region)

  tags = {
    Name = format("%s-subnet-private-1a", var.cluster_name)
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
# Create a Private Subnet B for K8S
resource "aws_subnet" "eks_subnet_private_1b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = format("%sb", var.aws_region)

  tags = {
    Name = format("%s-subnet-private-1b", var.cluster_name)
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
# Edit Route Table of Subnet Private A
resource "aws_route_table_association" "eks_private_rt_association_1a" {
  subnet_id      = aws_subnet.eks_subnet_private_1a.id
  route_table_id = aws_route_table.eks_nat_rt.id
}
# Edit Route Table of Subnet Private A
resource "aws_route_table_association" "eks_private_rt_association_1b" {
  subnet_id      = aws_subnet.eks_subnet_private_1b.id
  route_table_id = aws_route_table.eks_nat_rt.id
}

###
# Internet Gateway
###
# Internet Gateway allow Public Subnet to access Internet
resource "aws_internet_gateway" "eks_ig" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = format("%s-internet-gateway", var.cluster_name)
  }
}
# Add route 0.0.0.0/0 to in and out
resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_ig.id
  }
  tags = {
    Name = format("%s-public-rt", var.cluster_name)
  }
}

###
# Elastic IP
###
# This IP will be used on NAT Gateway
resource "aws_eip" "eks_eip" {
  vpc = true
  tags = {
    "Name" = format("%s-elastic-ip", var.cluster_name)
  }
}

###
# NAT Gateway
###

# Associate NAT Gateway with Public Subnet, this get one IP address \
# of Public Subnet and allow traffic there
resource "aws_nat_gateway" "eks_nat_gw" {
  allocation_id = aws_eip.eks_eip.id
  subnet_id     = aws_subnet.eks_subnet_public_1a.id
  tags = {
    Name = format("%s-nat-gateway", var.cluster_name)
  }
}
# Allow all traffic of hosts on Private to proxy on NAT Gateway
resource "aws_route_table" "eks_nat_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gw.id
  }
  tags = {
    Name = format("%s-private-rt", var.cluster_name)  
  }
}

###
# Output
###

# Print Subnet ID to use construct $eksctl
output "aws_subnet-public-1-id" {
  value = aws_subnet.eks_subnet_public_1a.id
}
# Print Subnet ID to use construct $eksctl
output "aws_subnet-public-2-id" {
  value = aws_subnet.eks_subnet_public_1b.id
}
# Print Subnet ID to use construct $eksctl
output "aws_subnet-private-1-id" {
  value = aws_subnet.eks_subnet_private_1a.id
}
# Print Subnet ID to use construct $eksctl
output "aws_subnet-private-2-id" {
  value = aws_subnet.eks_subnet_private_1b.id
}

###
#   Help to build EKS
###
output "eks_command_to_build" {
  value = var.eks_command
}