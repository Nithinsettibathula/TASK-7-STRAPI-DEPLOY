terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- Infrastructure Management ---
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["strapi-vpc"]
  }
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

# RDS Instance (db.t3.micro, Single-AZ)
resource "aws_db_instance" "strapi_db" {
  identifier          = "strapi-db-v3"
  instance_class      = "db.t3.micro"
  engine              = "postgres"
  allocated_storage   = 20
  db_name             = "strapidb"
  username            = "strapi_admin"
  password            = "SecurePass123!" 
  multi_az            = false
  skip_final_snapshot = true
  publicly_accessible = false
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "strapi-cluster-v3"
}

# Task Definition
resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::811738710312:role/ecsInstanceRole"
  task_role_arn            = "arn:aws:iam::811738710312:role/ecsInstanceRole"

  container_definitions = jsonencode([{
    name  = "strapi-app"
    image = "811738710312.dkr.ecr.us-east-1.amazonaws.com/strapi-repo:latest"
    portMappings = [{ containerPort = 1337, hostPort = 1337 }]
    environment = [
      { name = "DATABASE_HOST", value = aws_db_instance.strapi_db.address },
      { name = "DATABASE_CLIENT", value = "postgres" }
    ]
  }])
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "strapi-service-v3"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.subnets.ids
    assign_public_ip = true
  }
}