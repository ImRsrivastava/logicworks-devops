# --- ECR REPOSITORIES (Dono regions mein taaki local image pull ho sake) ---
resource "aws_ecr_repository" "primary" {
  provider             = aws.primary
  name                 = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "secondary" {
  provider             = aws.secondary
  name                 = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# --- IAM ROLES FOR ECS FARGATE ---
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  provider           = aws.primary
  name               = "${var.project_name}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  provider   = aws.primary
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "primary_ecs_sg" {
  provider = aws.primary
  name     = "${var.project_name}-primary-ecs-sg"
  vpc_id   = aws_vpc.primary.id

  ingress {
    from_port   = 8000
    to_port     = 8000
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

resource "aws_security_group" "secondary_ecs_sg" {
  provider = aws.secondary
  name     = "${var.project_name}-secondary-ecs-sg"
  vpc_id   = aws_vpc.secondary.id

  ingress {
    from_port   = 8000
    to_port     = 8000
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

# --- PRIMARY ECS CLUSTER + STAGING & PROD SERVICES ---
resource "aws_ecs_cluster" "primary" {
  provider = aws.primary
  name     = "${var.project_name}-primary-cluster"
}

resource "aws_cloudwatch_log_group" "primary_logs" {
  provider          = aws.primary
  name              = "/ecs/${var.project_name}-primary"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "primary_staging" {
  provider                 = aws.primary
  family                   = "${var.project_name}-primary-staging"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "fastapi-app"
    image     = "${aws_ecr_repository.primary.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    environment = [
      { name = "APP_ENV", value = "staging" },
      { name = "AWS_REGION", value = var.primary_region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.primary_logs.name
        "awslogs-region"        = var.primary_region
        "awslogs-stream-prefix" = "staging"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "primary_prod" {
  provider                 = aws.primary
  family                   = "${var.project_name}-primary-prod"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "fastapi-app"
    image     = "${aws_ecr_repository.primary.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    environment = [
      { name = "APP_ENV", value = "production" },
      { name = "AWS_REGION", value = var.primary_region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.primary_logs.name
        "awslogs-region"        = var.primary_region
        "awslogs-stream-prefix" = "prod"
      }
    }
  }])
}

resource "aws_ecs_service" "primary_staging" {
  provider        = aws.primary
  name            = "${var.project_name}-staging-svc"
  cluster         = aws_ecs_cluster.primary.id
  task_definition = aws_ecs_task_definition.primary_staging.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.primary_public[*].id
    security_groups  = [aws_security_group.primary_ecs_sg.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "primary_prod" {
  provider        = aws.primary
  name            = "${var.project_name}-prod-svc"
  cluster         = aws_ecs_cluster.primary.id
  task_definition = aws_ecs_task_definition.primary_prod.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.primary_public[*].id
    security_groups  = [aws_security_group.primary_ecs_sg.id]
    assign_public_ip = true
  }
}

# --- SECONDARY ECS CLUSTER + PROD DR SERVICE (us-east-1) ---
resource "aws_ecs_cluster" "secondary" {
  provider = aws.secondary
  name     = "${var.project_name}-secondary-cluster"
}

resource "aws_cloudwatch_log_group" "secondary_logs" {
  provider          = aws.secondary
  name              = "/ecs/${var.project_name}-secondary"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "secondary_prod" {
  provider                 = aws.secondary
  family                   = "${var.project_name}-secondary-prod"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "fastapi-app"
    image     = "${aws_ecr_repository.secondary.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    environment = [
      { name = "APP_ENV", value = "production-dr" },
      { name = "AWS_REGION", value = var.secondary_region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.secondary_logs.name
        "awslogs-region"        = var.secondary_region
        "awslogs-stream-prefix" = "prod-dr"
      }
    }
  }])
}

resource "aws_ecs_service" "secondary_prod" {
  provider        = aws.secondary
  name            = "${var.project_name}-prod-dr-svc"
  cluster         = aws_ecs_cluster.secondary.id
  task_definition = aws_ecs_task_definition.secondary_prod.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.secondary_public[*].id
    security_groups  = [aws_security_group.secondary_ecs_sg.id]
    assign_public_ip = true
  }
}