# Scale Based on CPU Utilization
resource "aws_autoscaling_policy" "scale_up_cpu" {
  name                   = "scale-up-cpu"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app_server_asg.name

  target_tracking_configuration {
    target_value = 60.0
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# Scale Based on Requests
resource "aws_autoscaling_policy" "scale_up_lb" {
  name                   = "scale-up-lb"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app_server_asg.name

  target_tracking_configuration {
    target_value = 10
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.wordpress_alb.arn_suffix}/${aws_lb_target_group.alb_target_grp.arn_suffix}"
    }
  }
}
