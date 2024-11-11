# Create public subnets for web tier
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = var.public_subnets_cidr[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.az[count.index]

  tags = {
    Name = "public-subnet-AZ-${count.index + 1}"
  }
}

# Create private subnets for application tier
resource "aws_subnet" "private_app_subnets" {
  count             = length(var.private_app_subnets_cidr)
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = var.private_app_subnets_cidr[count.index]
  availability_zone = var.az[count.index]

  tags = {
    Name = "private-app-subnet-AZ-${count.index + 1}"
  }
}

# Create private subnets for database tier
resource "aws_subnet" "private_db_subnets" {
  count             = length(var.private_db_subnets_cidr)
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = var.private_db_subnets_cidr[count.index]
  availability_zone = var.az[count.index]

  tags = {
    Name = "private-db-subnet-AZ-${count.index + 1}"
  }
}
