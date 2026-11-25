# Multi-Region High-Availability & Disaster Recovery CI/CD Pipeline on AWS

This repository implements an end-to-end, containerized CI/CD pipeline and multi-region infrastructure on AWS using **Terraform**, **Amazon ECS Fargate**, **Amazon ECR**, **Jenkins**, **CloudWatch**, and **SNS**.

## 1. Architecture Overview

The solution is designed for High Availability (HA) and Disaster Recovery (DR) across two AWS regions:

* **Primary Region (`ap-south-1` — Mumbai):**

  * Custom VPC with public/private subnets and NAT Gateway

  * Amazon ECR repository (`logicworks-devops-api`)

  * Amazon ECS Fargate Cluster (`logicworks-devops-primary-cluster`) running:

    * `logicworks-devops-staging-svc` (Staging environment)

    * `logicworks-devops-prod-svc` (Primary Production environment)

* **Secondary / DR Region (`ap-southeast-1` — Singapore):**

  * Custom VPC with public/private subnets and NAT Gateway

  * Replicated Amazon ECR repository (`logicworks-devops-api`)

  * Amazon ECS Fargate Cluster (`logicworks-devops-secondary-cluster`) running:

    * `logicworks-devops-prod-dr-svc` (Production Disaster Recovery environment)

* **CI/CD & Monitoring:**

  * Jenkins server hosted on EC2 in `ap-south-1` configured with an IAM Instance Role (`AmazonEC2ContainerRegistryPowerUser` + `AmazonECS_FullAccess`)

  * CloudWatch alarms and SNS email notifications for infrastructure and service health monitoring

## 2. Repository Structure

```
logicworks-devops/
├── app/                     # FastAPI sample application & Dockerfile
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── infra/                   # Multi-region Terraform Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── ...
├── Screenshots/             # Deployment, pipeline, ECS, and SNS verification proofs
├── Jenkinsfile              # Declarative multi-region CI/CD pipeline
└── README.md                # Step-by-step implementation guide

```

## 3. Prerequisites

* AWS Account with permissions for VPC, IAM, EC2, ECR, ECS, CloudWatch, and SNS

* Local machine with **Git**, **AWS CLI v2**, and **Terraform** installed

* GitHub repository (`ImRsrivastava/logicworks-devops`) with working code pushed to the `staging` branch

* Existing Jenkins EC2 instance running in `ap-south-1` with **Docker**, **Git**, and **AWS CLI v2** installed

## 4. Step-by-Step Implementation Guide

### Step 1: Configure Local AWS CLI & Push Code to `staging`

1. Configure AWS credentials locally with `ap-south-1` as the default region:

   ```
   aws configure
   aws sts get-caller-identity
   
   ```

2. Push the application, Terraform files, and `Jenkinsfile` to the `staging` branch:

   ```
   git checkout -b staging
   git add .
   git commit -m "Add multi-region Terraform infra and Jenkinsfile"
   git push -u origin staging
   
   ```

### Step 2: Provision Multi-Region Infrastructure with Terraform

1. Navigate to the `infra/` directory and initialize Terraform:

   ```
   cd infra
   terraform init
   
   ```

2. Review and apply the infrastructure across **Primary (`ap-south-1`)** and **Secondary DR (`ap-southeast-1`)**:

   ```
   terraform plan -var="alert_email=<YOUR_EMAIL>" -var="secondary_region=ap-southeast-1"
   terraform apply -var="alert_email=<YOUR_EMAIL>" -var="secondary_region=ap-southeast-1"
   
   ```

3. Open your email inbox and click **Confirm subscription** on the AWS SNS confirmation email.

### Step 3: Prepare the Jenkins EC2 Instance (`ap-south-1`)

1. Attach an IAM Role (`Logicworks-Jenkins-EC2-Role`) to the Jenkins EC2 instance with:

   * `AmazonEC2ContainerRegistryPowerUser`

   * `AmazonECS_FullAccess`

2. SSH into the Jenkins EC2 instance, install AWS CLI v2, and grant Docker access to the `jenkins` user:

   ```
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   sudo apt-get update && sudo apt-get install -y unzip
   unzip -q awscliv2.zip
   sudo ./aws/install
   rm -rf awscliv2.zip aws
   
   sudo usermod -aG docker jenkins
   sudo systemctl restart jenkins
   
   ```

### Step 4: Configure & Run the Jenkins Pipeline

1. Ensure `Jenkinsfile` points to the `staging` branch (`git branch: 'staging'`), your AWS Account ID, and `SECONDARY_REGION = "ap-southeast-1"`.

2. In Jenkins, create a new **Pipeline** job (`Logicworks-Pipeline`):

   * **Definition:** `Pipeline script from SCM`

   * **SCM:** `Git`

   * **Repository URL:** `https://github.com/ImRsrivastava/logicworks-devops.git`

   * **Branch Specifier:** `*/staging`

   * **Script Path:** `Jenkinsfile`

3. Click **Build Now** to execute the pipeline stages:

   1. **Source Checkout:** Pulls the latest commit from `staging`.

   2. **Build & Push Docker Image (Multi-Region):** Builds the FastAPI Docker image and pushes it to ECR in both `ap-south-1` and `ap-southeast-1`.

   3. **Deploy to Staging:** Updates `logicworks-devops-staging-svc` in `ap-south-1`.

   4. **Manual Approval for Production:** Pauses pipeline execution until an operator clicks **Approve & Deploy**.

   5. **Deploy to Production (Primary + DR):** Simultaneously updates `logicworks-devops-prod-svc` in Mumbai (`ap-south-1`) and `logicworks-devops-prod-dr-svc` in Singapore (`ap-southeast-1`).

## 5. Verification

1. **Jenkins Pipeline:** Confirm all stages including the manual approval gate complete with green status (`Screenshots/02-logicwork-production-approval.png`, `Screenshots/06-logicworks-pipeline-overview.png`).

2. **Primary Region (`ap-south-1`):** Open **ECS → Clusters → `logicworks-devops-primary-cluster`**, verify `staging-svc` and `prod-svc` tasks are `RUNNING`, copy the task Public IP, and test:

   ```
   curl http://<MUMBAI_PUBLIC_IP>:8000/health
   
   ```

3. **Secondary DR Region (`ap-southeast-1`):** Open **ECS → Clusters → `logicworks-devops-secondary-cluster`**, verify `prod-dr-svc` task is `RUNNING`, copy the task Public IP, and test:

   ```
   curl http://<SINGAPORE_PUBLIC_IP>:8000/health
   
   ```

4. **Alerts & Notifications:** Verify the SNS topic subscription status is `Confirmed` (`Screenshots/07-logicworks-sns.png`).

## 6. Cleanup (Cost Management)

Once verification and screenshots are complete, tear down all provisioned AWS resources to avoid ongoing charges:

```
cd infra
terraform destroy -var="alert_email=<YOUR_EMAIL>" -var="secondary_region=ap-southeast-1"

```