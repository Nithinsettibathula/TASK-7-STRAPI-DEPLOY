# Strapi CMS Deployment to AWS ECS
Nithin Settibathula
This project demonstrates the deployment of a **Strapi application** to **Amazon ECS (Fargate)** using **Terraform** and **GitHub Actions**. This was completed as part of my DevOps Internship (Task 7).

## 📌 Project Overview
The goal of this task was to automate the infrastructure setup and the deployment pipeline for a production-ready Strapi application on AWS.



## 🛠️ Tech Stack
* **Cloud Provider:** AWS (Account: `811738710312`)
* **Infrastructure as Code:** Terraform
* **CI/CD:** GitHub Actions
* **Database:** Amazon RDS PostgreSQL
* **Containerization:** Docker & Amazon ECR

## 🚀 Key Features
* **Automated Infrastructure:** Terraform was used to create the ECS Cluster, RDS Instance, and Security Groups.
* **CI/CD Pipeline:** GitHub Actions automatically builds the Docker image and deploys it to ECS on every push to the `main` branch.
* **Resource Optimization:** Configured **1024 CPU** and **2048 Memory** for application stability.
* **IAM Security:** Utilized the existing `ecs_fargate_taskRole` for secure task execution.

## 🔗 Project Links
* **Live App URL:** `http://YOUR_PUBLIC_IP:1337`
* **GitHub Repository:** [Insert your GitHub Link Here]

## 📖 How to Deploy
1. **Initialize Terraform:**
   ```powershell
   terraform init
   terraform apply -var="db_password=YourPassword" -auto-approve
