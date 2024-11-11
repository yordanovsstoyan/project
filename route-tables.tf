# Create public route table & configure internet access
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_igw.id
  }

  tags = {
    Name = "public_rt"
  }
}


# Associate public subnets with public route table
resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Create private route table for private app tier
resource "aws_route_table" "private_app_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-app-rt"
  }
}

# Associate private app subnets with private route table
resource "aws_route_table_association" "private_app_rt_assoc" {
  count          = length(aws_subnet.private_app_subnets)
  subnet_id      = aws_subnet.private_app_subnets[count.index].id
  route_table_id = aws_route_table.private_app_rt.id
}

# Create private route table for private database tier
resource "aws_route_table" "private_db_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-db-rt"
  }
}

# Associate private database subnets with private route table
resource "aws_route_table_association" "private_db_rt_assoc" {
  count          = length(aws_subnet.private_db_subnets)
  subnet_id      = aws_subnet.private_db_subnets[count.index].id
  route_table_id = aws_route_table.private_db_rt.id
}
