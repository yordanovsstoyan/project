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
