
# --- ECR REPOSITORY ---
resource "aws_ecr_repository" "strapi" {
  name                 = "strapi-app"
  force_delete         = true
  image_tag_mutability = "MUTABLE"
}

# --- IAM ROLES ---
resource "aws_iam_role" "ecs_exec_role" {
  name = "strapi-ecs-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_role_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
  publicly_accessible  = true # Set to false in high-security production
}

# --- ECS CLUSTER & TASK ---
resource "aws_ecs_cluster" "main" {
  name = "strapi-cluster"
}

resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn

  container_definitions = jsonencode([{
    name      = "strapi-container"
    image     = "${aws_ecr_repository.strapi.repository_url}:latest"
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