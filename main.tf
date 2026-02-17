terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 1. NETWORK: Use Default VPC as per Management Instruction ---
resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"
}

# --- 2. IAM: Reference Existing Roles provided in Support Channel ---
# Role: arn:aws:iam::811738710312:role/ecsInstanceRole
# Profile: ecsInstanceProfile
variable "instance_profile" {
  default = "ecsInstanceProfile"
}

# --- 3. ECS CLUSTER ---
resource "aws_ecs_cluster" "main" {
  name = "strapi-cluster-v3"
}

# --- 4. EC2 INSTANCE (To run the ECS Tasks) ---
# Management suggested a single EC2 if it works
resource "aws_instance" "ecs_node" {
  ami                    = "ami-0c101f26f147fa7fd" # Amazon Linux 2 ECS Optimized
  instance_type          = "t3.micro"
  iam_instance_profile   = var.instance_profile
  subnet_id              = aws_default_subnet.default_az1.id
  user_data              = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF

  tags = { Name = "strapi-ecs-node" }
}

# --- 5. TASK DEFINITION (Launch Type: EC2) ---
resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"] # Changed from Fargate to EC2
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::811738710312:role/ecsInstanceRole"

  container_definitions = jsonencode([{
    name  = "strapi-app"
    image = "811738710312.dkr.ecr.us-east-1.amazonaws.com/strapi-repo:latest"
    portMappings = [{ containerPort = 1337, hostPort = 1337 }]
    # Add your DB environment variables here
  }])
}

# --- 6. ECS SERVICE ---
resource "aws_ecs_service" "main" {
  name            = "strapi-service-v3"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  launch_type     = "EC2" # Changed from Fargate to EC2
  desired_count   = 1

  network_configuration {
    subnets          = [aws_default_subnet.default_az1.id]
    assign_public_ip = true
  }
}