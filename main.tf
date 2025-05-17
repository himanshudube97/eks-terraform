# Define local variables used across resources
locals {
    env         = "staging"                   # Environment name, used to tag resources (like staging, dev, prod)
    region      = "ap-south-1"                # AWS region to deploy resources into
    zone1       = "ap-south-1a"             # Specific availability zone (AZ) within the region
    eks_name    = "demo"                      # Name of the EKS cluster to be created later
    eks_version = "1.29"                      # EKS Kubernetes version
}

# Specify the cloud provider (AWS) and the region to use
provider "aws" {
    region = local.region
}

# Specify required Terraform version and required providers
terraform {
    required_version = ">= 1.0"  # Minimum Terraform version required

    required_providers {
        aws = {
            source  = "hashicorp/aws"       # The source of the provider (AWS from HashiCorp)
            version = "~> 5.49"             # Provider version constraint
        }
    }
}

# --- NETWORKING SETUP ---

# Create a Virtual Private Cloud (VPC)
resource "aws_vpc" "main" {  # "main" is the Terraform local name of the VPC resource
    cidr_block = "10.0.0.0/16"              # IP range for the entire VPC (large block)

    enable_dns_support   = true             # Enables internal DNS resolution within the VPC
    enable_dns_hostnames = true             # Enables DNS hostnames for instances in the VPC

    tags = {
        Name = "${local.env}-main"          # Tag used for identification in AWS Console
    }
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "igw" {  # "igw" is a local Terraform name, not a reserved word
    vpc_id = aws_vpc.main.id               # Attach the IGW to the VPC created above

    tags = {
        Name = "${local.env}-igw"          # Tag for IGW resource (Name is a special AWS tag key)
    } 
}

# Create a private subnet in the specified availability zone
resource "aws_subnet" "private_zone1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/19"         # Smaller subnet range inside the VPC
  availability_zone = local.zone1

  tags = {
    "Name"                                                 = "${local.env}-private-${local.zone1}"
    "kubernetes.io/role/internal-elb"                      = "1"  # For internal ELB support in Kubernetes
    "kubernetes.io/cluster/${local.env}-${local.eks_name}" = "owned"  # Tag for EKS cluster discovery
  }
}

# Create a public subnet in the same availability zone
resource "aws_subnet" "public_zone1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = local.zone1
  map_public_ip_on_launch = true              # Auto-assign public IPs to instances launched in this subnet

  tags = {
    "Name"                                                 = "${local.env}-public-${local.zone1}"
    "kubernetes.io/role/elb"                               = "1"  # For internet-facing load balancer
    "kubernetes.io/cluster/${local.env}-${local.eks_name}" = "owned"
  }
}

# --- NAT Gateway Setup ---

# Elastic IP for NAT Gateway — a public static IP address
resource "aws_eip" "nat" {
  domain = "vpc"                             # Required to associate the EIP with a NAT Gateway in a VPC

  tags = {
    Name = "${local.env}-nat"
  }
}

# NAT Gateway allows private subnets to access the internet securely
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id             # Associate the EIP with this NAT Gateway
  subnet_id     = aws_subnet.public_zone1.id # NAT Gateway must be in a public subnet to work

  tags = {
    Name = "${local.env}-nat"
  }

  depends_on = [aws_internet_gateway.igw]    # Ensure IGW is created before NAT Gateway
}

# --- Route Tables ---

# Private Route Table: directs internet-bound traffic via NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"             # Catch-all route for all internet-bound traffic
    nat_gateway_id = aws_nat_gateway.nat.id  # Use NAT Gateway for outbound access
  }

  tags = {
    Name = "${local.env}-private"
  }
}

# Public Route Table: directs internet-bound traffic via Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.env}-public"
  }
}

# --- Route Table Associations ---

# Associate private subnet with the private route table
resource "aws_route_table_association" "private_zone1" {
  subnet_id      = aws_subnet.private_zone1.id
  route_table_id = aws_route_table.private.id
}

# Associate public subnet with the public route table
resource "aws_route_table_association" "public_zone1" {
  subnet_id      = aws_subnet.public_zone1.id
  route_table_id = aws_route_table.public.id
}

# --------------------
# Concept Recap:
# --------------------
# - A subnet is considered public if:
#   1. It is associated with a route table that routes to an Internet Gateway.
#   2. It assigns public IPs to instances (map_public_ip_on_launch = true).
#
# - A subnet is private if:
#   1. It does NOT route to an Internet Gateway.
#   2. It routes to a NAT Gateway instead for outbound internet access.
#
# - Public subnet = direct internet access.
# - Private subnet = indirect internet access via NAT.
# - Internet Gateway = required for public resources (e.g., load balancers).
# - NAT Gateway = required for private resources (e.g., EKS nodes) to access internet without being exposed.
            #         Internet
            #            │
            #    +-------▼--------+
            #    | Internet Gateway| ← Attached to VPC, not subnet
            #    +-------+--------+
            #            │
            #    +-------▼--------+
            #    |  Public Subnet | ← Contains ALB and NAT Gateway
            #    | +------------+ |
            #    | | ALB        | |
            #    | | NAT GW     | |
            #    | +------------+ |
            #    +-------+--------+
            #            │
            #    +-------▼--------+
            #    | Private Subnet | ← EC2s, DBs, etc.
            #    +----------------+
