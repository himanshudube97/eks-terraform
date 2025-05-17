# Terraform AWS VPC with Public & Private Subnets, NAT Gateway, and Internet Gateway

This Terraform configuration provisions a secure and scalable VPC setup in AWS, including public and private subnets, an Internet Gateway (IGW), a NAT Gateway, and routing rules for internet access. It is ideal for environments like EKS (Elastic Kubernetes Service) where you want public access for load balancers and private networking for sensitive resources like databases or worker nodes.

---

## 🧱 Infrastructure Components

- **VPC**: Custom VPC with DNS support enabled.
- **Subnets**:
  - **Public Subnet**: For load balancers and NAT Gateway.
  - **Private Subnet**: For internal workloads like EKS nodes or databases.
- **Internet Gateway (IGW)**: Allows public subnets to communicate with the internet.
- **NAT Gateway**: Allows private subnets to send traffic to the internet without being directly exposed.
- **Elastic IP**: Static public IP for the NAT Gateway.
- **Route Tables**:
  - Public: Routes outbound traffic to IGW.
  - Private: Routes outbound traffic to NAT Gateway.
- **Route Table Associations**: Bind subnets to appropriate route tables.

---


