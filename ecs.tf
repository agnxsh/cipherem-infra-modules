locals {
  service_name_fmt = "node-%0${min(length(format("%d", var.number_of_nodes)), length(format("%s", var.number_of_nodes))) + 1}d-%s"
  ecs_cluster_name = "geth-${var.network_name}"
  ethereum_bucket  = "${var.region}-ecs-${lower(var.network_name)}-${random_id.bucket_postfix.hex}"
}

resource "aws_ecs_cluster" "ethereum" {
  name = local.ecs_cluster_name
}

resource "aws_ecs_task_definition" "go_ethereum" {
  family                   = "go-ethereum-${var.network_name}"
  container_definitions    = replace(element(compact(local.container_definitions), 0), "/\"(true|false|[0-9]+)\"/", "$1")
  requires_compatibilities = ["FARGATE"]
  cpu                      = "4096"
  memory                   = "8192"
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task.arn

  volume {
    name = local.shared_volume_name
  }
}

resource "aws_ecs_service" "go_ethereum" {
  count           = var.number_of_nodes
  name            = format(local.service_name_fmt, count.index + 1, var.network_name)
  cluster         = aws_ecs_cluster.ethereum.id
  task_definition = aws_ecs_task_definition.go_ethereum.arn
  launch_type     = "FARGATE"
  desired_count   = "1"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = var.is_public_subnets
    security_groups  = [aws_security_group.go_ethereum.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nlb_tg_go_ethereum.arn
    container_name   = local.go_ethereum_container_name
    container_port   = var.go_ethereum_rpc_port
  }
}

resource "random_id" "bucket_postfix" {
  byte_length = 8
}

data "aws_caller_identity" "this" {}

data "aws_iam_policy_document" "allow_all_access_within_account" {
  statement {
    sid     = "AllowAccess"
    actions = ["s3:*"]
    effect  = "Allow"

    resources = [
      "arn:aws:s3:::${local.ethereum_bucket}",
      "arn:aws:s3:::${local.ethereum_bucket}/*",
    ]

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
      type        = "AWS"
    }
  }
}


resource "aws_s3_bucket" "ethereum" {
  bucket        = local.ethereum_bucket
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "versioning_ethereum" {
  bucket = aws_s3_bucket.ethereum.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "allow_all_access_within_account" {
  bucket = aws_s3_bucket.ethereum.id
  policy = data.aws_iam_policy_document.allow_all_access_within_account.json
}