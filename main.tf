# --- PROVIDER CONFIGURATION ---
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "strapi-task" 
}

# --- NETWORKING (Using existing VPC 'strapi-vpc') ---
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["strapi-vpc"]
  }
}

data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# --- DB SUBNET GROUP (Fixes the VPC Mismatch Error) ---
resource "aws_db_subnet_group" "strapi_db_subnet" {
  name       = "strapi-db-subnet-group-final"
  subnet_ids = data.aws_subnets.existing.ids

  tags = { Name = "Strapi DB Subnet Group" }
}

# --- SECURITY GROUPS ---
resource "aws_security_group" "ecs_sg" {
  name   = "strapi-ecs-sg-v3"
  vpc_id = data.aws_vpc.existing.id
  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name   = "strapi-rds-sg-v3"
  vpc_id = data.aws_vpc.existing.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
}

# --- RDS POSTGRES (Instruction: db.t3.micro, Single-AZ) ---
resource "aws_db_instance" "strapi_db" {
  identifier           = "strapi-db-task-final"
  instance_class       = "db.t3.micro"      
  engine               = "postgres"
  engine_version       = "14"
  allocated_storage    = 20
  db_name              = "strapidb"
  username             = "strapi_admin"
  password             = "SecurePass123!" 
  multi_az             = false            
  skip_final_snapshot  = true
  
  # Links RDS to the correct VPC subnets
  db_subnet_group_name = aws_db_subnet_group.strapi_db_subnet.name
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible  = false
}

# --- ECR REPOSITORY (Using Existing) ---
data "aws_ecr_repository" "strapi_repo" {
  name = "strapi-repo"
}

# --- ECS CLUSTER & SERVICE ---
# We use a unique name to avoid the "ClusterContainsServicesException" on the old one
resource "aws_ecs_cluster" "main" { name = "strapi-cluster-v3" }

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
    image = "${data.aws_ecr_repository.strapi_repo.repository_url}:latest"
    portMappings = [{ containerPort = 1337, hostPort = 1337 }]
    environment = [
      { name = "DATABASE_HOST",     value = aws_db_instance.strapi_db.address },
      { name = "DATABASE_PORT",     value = "5432" },
      { name = "DATABASE_NAME",     value = "strapidb" },
      { name = "DATABASE_USERNAME", value = "strapi_admin" },
      { name = "DATABASE_PASSWORD", value = "SecurePass123!" },
      { name = "DATABASE_CLIENT",   value = "postgres" },
      { name = "NODE_ENV",          value = "production" }
    ]
  }])
}

resource "aws_ecs_service" "main" {
  name            = "strapi-service-v3"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.existing.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}