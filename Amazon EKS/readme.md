# k8s-earth -> Amazon EKS
Repo of K8S at IaC to rebuild my environment with Amazon EKS

### network-handson
> You can create your network and edit resources

### network-module
> You can create same network but with code clean


> I used Terraform to build Network architecture to gain time

Hello friend, this manifest will help you to build a EKS network with Terraform,
but you dont't need this terraform, because command eksctl build everything and network too, with one command :D
this terraform can help you understand how something works when you can't use eksctl just like at this cases.


### Terraform DOC
At this file exist all configuration nedded to K8S Network
This files following AWS Documentaion for terraform
https://registry.terraform.io/providers/hashicorp/aws/latest/docs

Amazon EKS networking
https://docs.aws.amazon.com/eks/latest/userguide/eks-networking.html


### Resume of this file
>Create a VPC, with 2 public subnet and 2 private subnet
>Create a Elastic IP, Internet Gateway and Nat Gateway
>This is a basic Network infrasestructure to create a EKS
>After running this terraformation you need execute command eksclt

### After build VPC and Subnets
This command build EKS Cluster with 2 Subnets private and 2 Subnets public
https://eksctl.io/usage/vpc-networking/

> :warning: ** Do not use eksctl to create a cluster or nodes in an AWS Region where you have AWS Outposts, AWS Wavelength, or AWS Local Zones enabled. Create a cluster and self-managed nodes using the Amazon EC2 API or AWS CloudFormation instead. For more information, see To launch self-managed Linux nodes using the AWS Management Console and To launch self-managed Windows nodes using the AWS Management Console.


```
eksctl create cluster --name myCluster --version 1.18 \
    --region us-east-1 --managed --nodes 2 --nodes-min 1 --nodes-max 3 \
    --vpc-private-subnets=subnet-01c79b7b090b5199c,subnet-0f6efb0ee6d338ea6 \
    --vpc-public-subnets=subnet-0063e09cc658b0943,subnet-0dc1380dc72a626a2
```

### Cost
https://aws.amazon.com/ec2/pricing/on-demand/

```
###
#   Cost
#   https://aws.amazon.com/ec2/pricing/on-demand/
###
   m5.large x2 instance  = 0,096 USD/0,192/hour  x 24 hours     = $4,61/day
   NAT Gateway           = 0,045 USD/hours       x 24 hours     = $1,08/day
   Elastic IP            = 0,005 USB/hours       x 24 hours     = $0,12/day
   Cluster Kubernetes    = 0,10 USD/hour         x 24 hours     = $2,40/day
   Tax (Maybe)                                                  = + 14%

   
   Total Cost            = 0,246/hour USD                       = $9,36/day


| Object     | HOUR  | QUANTITY | TOTAL DAY |
+------------+-------+----------+-----------+
| m5.large   | 0,096 |   2      | 4,61 USD  |
| NAT Gat    | 0,045 |   1      | 1,08 USD  |
| Elastic IP | 0,005 |   1      | 0,12 USD  |
| Cluster K8s| 0,10  |   1      | 2,40 USD  |
|            |       |          |           |
| Total      |       |          | 9,36 USD  |
```