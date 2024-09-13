output "vpc_id" {
  value = aws_vpc.bahmni-vpc.id
}

output "vpc_public_subnets" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "vpc_private_subnets" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}