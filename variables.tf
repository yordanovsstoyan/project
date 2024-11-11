# AWS region
variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "aws region"
}

# VPC name
variable "vpc_name" {
  type        = string
  default     = "project-vpc"
  description = "name of VPC"
}

# VPC CIDR
variable "vpc_cidr" {
  type        = string
  default     = "172.20.0.0/20"
  description = "VPC CIDR block"
}

# Public subnets CIDR list
variable "public_subnets_cidr" {
  type        = list(string)
  default     = ["172.20.1.0/24", "172.20.2.0/24"]
  description = "public subnets CIDR"
}

# Private app subnets CIDR list
variable "private_app_subnets_cidr" {
  type        = list(string)
  default     = ["172.20.3.0/24", "172.20.4.0/24"]
  description = "private app subnets CIDR"
}

# Private db subnets CIDR list
variable "private_db_subnets_cidr" {
  type        = list(string)
  default     = ["172.20.5.0/24", "172.20.6.0/24"]
  description = "private database subnets CIDR"
}

# Subnets availability zones
variable "az" {
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
  description = "availability zones"
}

# RDS subnet group name
variable "wordpressdb_subnet_grp" {
  type        = string
  default     = "wordpress-db-subnet-grp"
  description = "name of RDS subnet group"
}

# RDS primary instance identity
variable "primary_rds_identifier" {
  type        = string
  default     = "wordpress-rds-instance"
  description = "Identifier of primary RDS instance"
}

# RDS replica identity
variable "replica_rds_identifier" {
  type        = string
  default     = "wordpress-rds-instance-replica"
  description = "Identifier of replica RDS instance"
}

# Type of RDS instance
variable "db_instance_type" {
  type        = string
  default     = "db.t3.micro"
  description = "type/class of RDS database instance"
}
variable "db_storage" {
  type        = string
  default     = "10"
  description = "Allocated Storage For DB"
}
variable "db_engine" {
  type        = string
  default     = "mysql"
  description = "Database Engine"
}
variable "db_engine_version" {
  type        = string
  default     = "8.0.32"
  description = "Database Engine Version"
}
# RDS instance name
variable "database_name" {
  type        = string
  default     = "wordpress_DB"
  description = "name of RDS instance"
}

# RDS instance username
variable "database_user" {
  type        = string
  description = "name of RDS instance user"
  default     = "dbuser"
}

# ID of EC2 instance AMI
variable "ami" {
  type        = string
  default     = "ami-0ea3c35c5c3284d82"
  description = "ID of Instance AMI"
}

# Type of instance
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "type/class of instance"
}

variable "asg_min_size" {
  type        = string
  default     = "2"
  description = "Min Size For Autoscaling Group"
}
variable "asg_max_size" {
  type        = string
  default     = "4"
  description = "Max Size For Autoscaling Group"
}
variable "asg_desired_size" {
  type        = string
  default     = "2"
  description = "Desired Size For Autoscaling Group"
}
