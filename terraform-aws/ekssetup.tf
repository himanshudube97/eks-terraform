#Iam user
resource "aws_iam_role" "eks" { #creating a role for the EKS control plane
  name = "${local.env}-${local.eks_name}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks" { # Attaching the AmazonEKSClusterPolicy to the role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

# aws_eks_cluster	Actually creates the EKS control plane (i.e. the cluster), using the role and some VPC settings.
resource "aws_eks_cluster" "eks" { # Creating the EKS cluster using the role and VPC settings
  name     = "${local.env}-${local.eks_name}"
  version  = local.eks_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true

#The two private subnet IDs you provided are used by AWS EKS to place internal Elastic Network Interfaces (ENIs) for the control plane. These ENIs allow the control plane to communicate with your worker nodes and other AWS services inside your VPC.
    subnet_ids = [ 
      aws_subnet.private_zone1.id,
      aws_subnet.private_zone2.id
    ]
# Even though the control plane itself is fully managed by AWS and not directly inside your VPC, AWS still creates ENIs in your VPC subnets to:
# Communicate with worker nodes
# Manage Kubernetes networking
# Integrate with VPC-native features (like security groups, ELBs, etc.)
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks]
}



# ENI stands for Elastic Network Interface.

# It is a virtual network card in AWS — just like a network adapter on a physical computer or a VM.

# 🧠 Think of it like this:
# An ENI is how AWS resources like EC2 instances or EKS control planes connect to your VPC — it's their "network port" that gives them an IP address and lets them send/receive data.
# As we do the setup of EKS, the ENIs are created in the private subnets you specified. This allows the EKS control plane to communicate with your worker nodes and other AWS services securely within your VPC.