resource "aws_route_table" "public" {
  vpc_id = aws_vpc.bahmni-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name  = "bahmni-rt-public-${var.vpc_suffix}"
    owner = var.owner
  }
}
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.bahmni-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_az_a.id
  }
  tags = {
    Name  = "bahmni-rt-private-a-${var.vpc_suffix}"
    owner = var.owner
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.bahmni-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_az_b.id
  }
  tags = {
    Name  = "bahmni-rt-private-b-${var.vpc_suffix}"
    owner = var.owner
  }
}

resource "aws_route_table_association" "private_a" {
  route_table_id = aws_route_table.private_a.id
  subnet_id      = aws_subnet.private_a.id
}
resource "aws_route_table_association" "private_b" {
  route_table_id = aws_route_table.private_b.id
  subnet_id      = aws_subnet.private_b.id
}

resource "aws_route_table_association" "public_a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_a.id
}

resource "aws_route_table_association" "public_b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_b.id
}
