output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "The private IP address of the main server instance to use on eksctl."
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "The public IP address of the main server instance to use on eksctl."
}

output "eks_command_to_build" {
  value = var.eks_command
}