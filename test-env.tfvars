# AWS region
aws_region = "us-east-2"
# VPC name
vpc_name = "project-vpc"
# VPC CIDR
vpc_cidr = "172.20.0.0/20"
# Public subnets CIDR list
public_subnets_cidr = ["172.20.1.0/24", "172.20.2.0/24"]
# Private app subnets CIDR list
private_app_subnets_cidr = ["172.20.3.0/24", "172.20.4.0/24"]
# Private db subnets CIDR list
private_db_subnets_cidr = ["172.20.5.0/24", "172.20.6.0/24"]
# Availability zones
az = ["us-east-2a", "us-east-2b"]
# RDS subnet group name
wordpressdb_subnet_grp = "wordpress-db-subnet-grp"
# RDS primary instance identity
primary_rds_identifier = "wordpress-rds-instance"
# RDS replica identity
replica_rds_identifier = "wordpress-rds-instance-replica"
# Type of RDS instance
db_instance_type = "db.t3.micro"
# DB storage allocation
db_storage = "10"
# Database engine
db_engine = "mysql"
# Database engine version
db_engine_version = "8.0.32"
# RDS instance name
database_name = "wordpress_DB"
# RDS instance username
database_user = "dbuser"
# ID of EC2 instance AMI
ami = "ami-0ea3c35c5c3284d82"
# Type of EC2 instance
instance_type = "t3.micro"
# Autoscaling group minimum size
asg_min_size = "2"
# Autoscaling group maximum size
asg_max_size = "4"
# Autoscaling group desired size
asg_desired_size = "2"
