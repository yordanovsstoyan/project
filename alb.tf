resource "aws_lb" "wordpress_alb" {
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
