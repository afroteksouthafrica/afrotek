locals {
  name = "${var.project}-${var.env}"
  tags = { Project = var.project, Env = var.env }
}

# --- VPC (2 public subnets, internet-facing) ---
resource "aws_vpc" "this" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "af-south-1a"
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${local.name}-public-a" })
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = "af-south-1b"
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${local.name}-public-b" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-public-rt" })
}
resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --- ECS cluster ---
resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = local.tags
}

# --- IAM roles for ECS task ---
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_exec" {
  name               = "${local.name}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.tags
}
resource "aws_iam_role_policy_attachment" "task_exec_policy" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_role" {
  name               = "${local.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.tags
}

# --- Logs ---
resource "aws_cloudwatch_log_group" "auth" {
  name              = "/ecs/${local.name}-auth"
  retention_in_days = 14
  tags              = local.tags
}

# --- ALB + SGs ---
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_lb" "alb" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = local.tags
}

resource "aws_lb_target_group" "auth_tg" {
  name        = "${local.name}-auth-tg"
  port        = 8001
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id
  health_check {
    path                = "/health"
    interval            = 20
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
    matcher             = "200"
  }
  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_tg.arn
  }
}

# --- Service SG ---
resource "aws_security_group" "svc_sg" {
  name   = "${local.name}-svc-sg"
  vpc_id = aws_vpc.this.id

  # Allow ALB to reach the task on 8001
  ingress {
    from_port       = 8001
    to_port         = 8001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# Allow ALB -> service on port 3002 (product)
resource "aws_security_group_rule" "svc_allow_3002_from_alb" {
  type                     = "ingress"
  from_port                = 3002
  to_port                  = 3002
  protocol                 = "tcp"
  security_group_id        = aws_security_group.svc_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

# --- Task Definition ---
resource "aws_ecs_task_definition" "auth" {
  family                   = "${local.name}-auth"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([
    {
      name         = "auth"
      image        = var.auth_image
      essential    = true
      portMappings = [{ containerPort = 8001, hostPort = 8001, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-region        = "af-south-1",
          awslogs-group         = aws_cloudwatch_log_group.auth.name,
          awslogs-stream-prefix = "auth"
        }
      }
      environment = []
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  tags = local.tags
}

# --- ECS Service ---
resource "aws_ecs_service" "auth" {
  name                   = "${local.name}-auth"
  cluster                = aws_ecs_cluster.this.id
  launch_type            = "FARGATE"
  desired_count          = 1
  task_definition        = aws_ecs_task_definition.auth.arn
  enable_execute_command = false

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.svc_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth_tg.arn
    container_name   = "auth"
    container_port   = 8001
  }

  depends_on = [aws_lb_listener.http]
  tags       = local.tags
}

######################
# Product service (health-proxy)
######################

# Target group for product on :3002
resource "aws_lb_target_group" "product_tg" {
  name        = "${local.name}-product-tg"
  port        = 3002
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = "/health"
    interval            = 20
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
    matcher             = "200"
  }

  tags = local.tags
}

# Listener rules: route /product/* to product_tg (HTTP + HTTPS)
resource "aws_lb_listener_rule" "product_http" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_tg.arn
  }

  condition {
    path_pattern { values = ["/product/*"] }
  }
}

# HTTPS listener rule intentionally omitted until HTTPS/ACM is configured.

# Task definition for product
resource "aws_ecs_task_definition" "product" {
  family                   = "${local.name}-product"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name         = "product"
      image        = var.product_image
      essential    = true
      portMappings = [{ containerPort = 3002, hostPort = 3002, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-region        = "af-south-1",
          awslogs-group         = aws_cloudwatch_log_group.auth.name, # reuse same LG or make a new one if you want
          awslogs-stream-prefix = "product"
        }
      }
      environment = []
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# Service for product
resource "aws_ecs_service" "product" {
  name            = "${local.name}-product"
  cluster         = aws_ecs_cluster.this.id
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.product.arn

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.svc_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.product_tg.arn
    container_name   = "product"
    container_port   = 3002
  }

  depends_on = [
    aws_lb_target_group.product_tg,
    aws_lb_listener.http
  ]

  tags = local.tags
}

