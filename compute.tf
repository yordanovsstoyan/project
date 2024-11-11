# Create elastic file system
resource "aws_efs_file_system" "wordpress_EFS" {
  creation_token = "wordpress-EFS"

  tags = {
    Name = "wordpress-EFS"
  }
}

# Mount efs on targets
resource "aws_efs_mount_target" "efs_mount" {
  count           = length(aws_subnet.private_app_subnets.*.id)
  file_system_id  = aws_efs_file_system.wordpress_EFS.id
  subnet_id       = element(aws_subnet.private_app_subnets.*.id, count.index)
  security_groups = [aws_security_group.efs_sg.id]
}

# ------------------------------------------------

resource "aws_lb" "wordpress_alb" {
  #depends_on = [aws_s3_bucket.lb_logs]
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnets.*.id
  # Enable access logging for ELB
  access_logs {
    bucket  = aws_s3_bucket.lb_logs.id
    enabled = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "alb_target_grp" {
  name        = "wordpress-alb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.project_vpc.id
  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 15
    matcher             = 200
    path                = "/"
    timeout             = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_grp.arn
  }
}

# -------------------------------------------------

# Launch template for application servers
resource "aws_launch_template" "app_server_lt" {
  name     = "app-server-LT"
  image_id = var.ami
  monitoring {
    enabled = true
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.asg.id
  }
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_server_sg.id, aws_security_group.efs_sg.id]
  user_data = base64encode(templatefile("${path.module}/userdata.tpl", {
    db_username           = var.database_user
    db_user_password      = random_password.db.result
    db_name               = var.database_name
    db_endpoint           = aws_db_instance.wordpress_db.endpoint
    efs_DNS               = aws_efs_file_system.wordpress_EFS.id
    ssm_cloudwatch_config = aws_ssm_parameter.cw_agent.name
  }))

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_db_instance.wordpress_db, aws_efs_file_system.wordpress_EFS, aws_efs_mount_target.efs_mount]
}

# Autoscaling group for application servers
resource "aws_autoscaling_group" "app_server_asg" {
  name_prefix         = "app-server-ASG"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_size
  vpc_zone_identifier = aws_subnet.private_app_subnets.*.id
  target_group_arns   = [aws_lb_target_group.alb_target_grp.arn]
  enabled_metrics     = ["GroupInServiceInstances", "GroupPendingInstances", "GroupTerminatingInstances"]

  launch_template {
    id      = aws_launch_template.app_server_lt.id
    version = "$Default"
  }

  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_db_instance.wordpress_db, aws_efs_file_system.wordpress_EFS, aws_efs_mount_target.efs_mount]
}

###
resource "aws_iam_role" "asg" {
  assume_role_policy = data.aws_iam_policy_document.trust_ec2.json
}

data "aws_iam_policy_document" "trust_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.asg.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.asg.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_base" {
  name = "AllowBase"
  role = aws_iam_role.asg.name

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "ssm:GetParameter"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "asg" {
  role = aws_iam_role.asg.name
}
