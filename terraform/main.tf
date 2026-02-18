# --- VPC & Subnets ---
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- CREATE CUSTOM IAM ROLE (To fix the "Role is not valid" error) ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "strapi-execution-role-nithin-v5"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- ECR REPOSITORY ---
resource "aws_ecr_repository" "strapi" {
  name         = "strapi-app"
  force_delete = true
}

# --- ECS CLUSTER ---
resource "aws_ecs_cluster" "main" {
  name = "strapi-cluster"
}

# --- SECURITY GROUP ---
resource "aws_security_group" "ecs_sg" {
  name   = "strapi-ecs-sg-v5"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- RDS POSTGRES (Added back to fix output error) ---
resource "aws_db_instance" "strapi_db" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t4g.micro"
  db_name              = "strapi"
  username             = "strapi_admin"
  password             = var.db_password
  skip_final_snapshot  = true
  publicly_accessible  = true 
}

# --- ECS TASK DEFINITION ---
resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "strapi-container"
    image     = "811738710312.dkr.ecr.us-east-1.amazonaws.com/strapi-app:latest"
    essential = true
    portMappings = [{ containerPort = 1337, hostPort = 1337 }]
    environment = [
      { name = "DATABASE_CLIENT", value = "postgres" },
      { name = "DATABASE_HOST", value = aws_db_instance.strapi_db.address },
      { name = "DATABASE_PORT", value = "5432" },
      { name = "DATABASE_NAME", value = "strapi" },
      { name = "DATABASE_USERNAME", value = "strapi_admin" },
      { name = "DATABASE_PASSWORD", value = var.db_password },
      { name = "NODE_ENV", value = "production" }
    ]
  }])
}

# --- ECS SERVICE ---
resource "aws_ecs_service" "strapi" {
  name            = "strapi-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}