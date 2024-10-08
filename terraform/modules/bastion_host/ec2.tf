resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  user_data                   = templatefile("${path.module}/user_data.tpl", {})
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "OpenMRS Bastion - ${var.vpc_suffix} VPC"
  }
}

