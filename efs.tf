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
