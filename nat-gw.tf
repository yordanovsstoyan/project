# Create elastic ip for NAT gateway
resource "aws_eip" "eip_natgw" {
  #   domain = "vpc"
}

# Create NAT gateway & allocate elastic ip
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip_natgw.id
  subnet_id     = element(aws_subnet.public_subnets, 0).id

  tags = {
    Name = "NAT-gw"
  }

  depends_on = [aws_internet_gateway.vpc_igw]
}
