resource "aws_efs_file_system" "openmrs-efs" {
  creation_token   = "efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
  tags = {
    Name = "openmrs-efs-${var.environment}"
  }
}

resource "aws_efs_mount_target" "openmrs-efs-mt-1" {
  file_system_id  = aws_efs_file_system.openmrs-efs.id
  subnet_id       = data.aws_subnets.private_subnets.ids[0]
  security_groups = [aws_security_group.openmrs-efs-sg.id]
}

resource "aws_efs_mount_target" "openmrs-efs-mt-2" {
  file_system_id  = aws_efs_file_system.openmrs-efs.id
  subnet_id       = data.aws_subnets.private_subnets.ids[1]
  security_groups = [aws_security_group.openmrs-efs-sg.id]
}

resource "aws_ssm_parameter" "efs_file_system_id" {
  name        = "/${var.environment}/efs/file_system_id"
  description = "File system id for EFS ${var.environment}"
  type        = "String"
  value       = aws_efs_file_system.openmrs-efs.id
}