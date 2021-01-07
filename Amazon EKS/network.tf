# Terraform DOC
# At this file exist all configuration nedded to K8S Network
# This files following AWS Documentaion for terraform
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs

# Amazon EKS networking
# https://docs.aws.amazon.com/eks/latest/userguide/eks-networking.html

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
    vpc_id = aws_vpc.myvpc.id

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
    vpc_id = aws_vpc.myvpc.id

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
  availability_zone = format("%sa", var.region)

  tags = {
    Name = format("%s-subnet-private-1a", var.cluster_name)
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
# Create a Private Subnet B for K8S
resource "aws_subnet" "eks_subnet_private_1b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = format("%sb", var.region)

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
# NAT Gateway
###
# NAT Gateway allow Private Subnet to access Internet
resource "aws_eip" "eks_eip" {
  vpc = true
  tags = {
    "Name" = format("%s-elastic-ip", var.cluster_name)
  }
}
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

