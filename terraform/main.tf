# --- VPC & Subnets ---
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
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
  name   = "strapi-ecs-sg-8117-final-v4"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5432
    to_port     = 5432
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

# --- RDS POSTGRES ---
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
  cpu                      = "1024"
  memory                   = "2048"
  
  execution_role_arn       = "arn:aws:iam::811738710312:role/ecs_fargate_taskRole"
  task_role_arn            = "arn:aws:iam::811738710312:role/ecs_fargate_taskRole"

  container_definitions = jsonencode([{
    name      = "strapi-container"
    image     = "811738710312.dkr.ecr.us-east-1.amazonaws.com/strapi-app:latest"
    essential = true
    portMappings = [{ containerPort = 1337, hostPort = 1337 }]
    
    # Log configuration తీసేశాను (పర్మిషన్ ఎర్రర్ రాకుండా)
    
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
  name            = "strapi-service-v2"
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