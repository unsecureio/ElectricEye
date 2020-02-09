resource "aws_ecs_cluster" "Electric_Eye_ECS_Cluster" {
  name = "${var.Electric_Eye_VPC_Name_Tag}-ecs-cluster"
}
resource "aws_s3_bucket" "Electric_Eye_Security_Artifact_Bucket" {
  bucket = "${var.Electric_Eye_ECS_Resources_Name}-artifact-bucket-${var.AWS_Region}-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }
}
resource "aws_ssm_parameter" "Electric_Eye_Bucket_Parameter" {
  name  = "electriceye-bucket"
  type  = "String"
  value = "${aws_s3_bucket.Electric_Eye_Security_Artifact_Bucket.id}"
}
resource "aws_cloudwatch_log_group" "Electric_Eye_ECS_Task_Definition_CW_Logs_Group" {
  name = "/ecs/${var.Electric_Eye_ECS_Resources_Name}"
}
resource "aws_ecs_task_definition" "Electric_Eye_ECS_Task_Definition" {
  family                   = "electric-eye"
  execution_role_arn       = "${aws_iam_role.Electric_Eye_ECS_Task_Execution_Role.arn}"
  task_role_arn            = "${aws_iam_role.Electric_Eye_ECS_Task_Role.arn}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096

  container_definitions = <<DEFINITION
[
  {
    "cpu": 2048,
    "image": "${var.Electric_Eye_Docker_Image_URI}",
    "memory": 4096,
    "memoryReservation": 4096,
    "essential": true,
    "environment": [],
    "name": "${var.Electric_Eye_ECS_Resources_Name}",
    "networkMode": "awsvpc",
    "logConfiguration": {
      "logDriver": "awslogs",
      "secretOptions": null,
      "options": {
        "awslogs-group": "/ecs/${var.Electric_Eye_ECS_Resources_Name}",
        "awslogs-region": "${var.AWS_Region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "portMappings": [],
    "volumesFrom": [],
    "mountPoints": [],
    "secrets": [
      {
        "valueFrom": "${aws_ssm_parameter.Electric_Eye_Bucket_Parameter.arn}",
        "name": "SH_SCRIPTS_BUCKET"
      }
    ]
  }
]
DEFINITION
}
resource "aws_iam_role" "Electric_Eye_ECS_Task_Execution_Role" {
  name               = "${var.Electric_Eye_ECS_Resources_Name}-exec-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "Electric_Eye_Task_Execution_Role_Policy" {
  name   = "${var.Electric_Eye_ECS_Resources_Name}-exec-policy"
  role   = "${aws_iam_role.Electric_Eye_ECS_Task_Execution_Role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "kms:Decrypt",
        "kms:DescribeKey",
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role" "Electric_Eye_ECS_Task_Role" {
  name               = "${var.Electric_Eye_ECS_Resources_Name}-task-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "Electric_Eye_Task_Role_Policy" {
  name   = "${var.Electric_Eye_ECS_Resources_Name}-task-policy"
  role   = "${aws_iam_role.Electric_Eye_ECS_Task_Role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "kms:Decrypt",
        "kms:DescribeKey",
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_cloudwatch_event_rule" "Electric_Eye_Task_Scheduling_CW_Event_Rule" {
  name                = "${var.Electric_Eye_ECS_Resources_Name}-scheduler"
  description         = "Run ${var.Electric_Eye_ECS_Resources_Name} Task at a scheduled time (${var.Electric_Eye_Schedule_Task_Expression}) - Managed by Terraform"
  schedule_expression = "${var.Electric_Eye_Schedule_Task_Expression}"
}
resource "aws_iam_role" "Electric_Eye_Scheduled_Task_Event_Role" {
  name               = "${var.Electric_Eye_ECS_Resources_Name}-event-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "Electric_Eye_Scheduled_Task_Event_Role_Policy" {
  role       = "${aws_iam_role.Electric_Eye_Scheduled_Task_Event_Role.id}"
  policy_arn = "${data.aws_iam_policy.AWS_Managed_ECS_Events_Role.arn}"
}
resource "aws_cloudwatch_event_target" "Electric_Eye_Scheduled_Scans" {
  rule       = "${aws_cloudwatch_event_rule.Electric_Eye_Task_Scheduling_CW_Event_Rule.name}"
  arn        = "${aws_ecs_cluster.Electric_Eye_ECS_Cluster.arn}"
  role_arn   = "${aws_iam_role.Electric_Eye_Scheduled_Task_Event_Role.arn}"
  ecs_target = {
      launch_type         = "FARGATE"
      task_definition_arn = "${aws_ecs_task_definition.Electric_Eye_ECS_Task_Definition.arn}"
      task_count          = "1"
      platform_version    = "LATEST"
      network_configuration  {
        subnets         = ["${element(aws_subnet.Electric_Eye_Public_Subnets.*.id, count.index)}"]
        security_groups = ["${aws_security_group.Electric_Eye_Sec_Group.id}"]
    }
  }
}