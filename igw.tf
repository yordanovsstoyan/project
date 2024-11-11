# Create internet gateway
resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "vpc-igw"
  }
}
