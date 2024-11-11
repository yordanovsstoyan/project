# RDS endpoint
output "RDS_endpoint" {
  value = aws_db_instance.wordpress_db.endpoint
}

# Loadbalancer DNS name
output "ALB_DNS" {
  value = aws_lb.wordpress_alb.dns_name
}
