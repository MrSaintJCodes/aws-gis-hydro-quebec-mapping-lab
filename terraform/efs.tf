resource "aws_efs_file_system" "opengis" {
  encrypted = true

  tags = {
    Name = "${local.name}-efs"
  }
}

resource "aws_efs_mount_target" "opengis" {
  count = 2

  file_system_id  = aws_efs_file_system.opengis.id
  subnet_id       = aws_subnet.private_app[count.index].id
  security_groups = [aws_security_group.efs.id]
}