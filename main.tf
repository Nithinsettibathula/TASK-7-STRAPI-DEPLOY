terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 1. NETWORK: Use Default VPC as per management instruction ---
resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"
}

# --- 2. ECS CLUSTER ---
resource "aws_ecs_cluster" "main" {
  name = "strapi-cluster-v3"
}

# --- 3. TASK DEFINITION (Launch Type: EC2) ---
resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"] # Management rule: Switch to EC2
  cpu                      = "256"
  memory                   = "512"
  
  # References the existing role provided in the support channel
  execution_role_arn       = "arn:aws:iam::811738710312:role/ecsInstanceRole"

  container_definitions = jsonencode([{
    name  = "strapi-app"
    image = "811738710312.dkr.ecr.us-east-1.amazonaws.com/strapi-repo:latest"
    portMappings = [{ containerPort = 1337, hostPort = 1337 }]
  }])
}

# --- 4. ECS SERVICE (Launch Type: EC2) ---
resource "aws_ecs_service" "main" {
  name            = "strapi-service-v3"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  launch_type     = "EC2" # Management rule: Switch to EC2
  desired_count   = 1

  network_configuration {
    subnets          = [aws_default_subnet.default_az1.id]
    assign_public_ip = true
  }
}