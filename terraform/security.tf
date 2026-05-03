resource "aws_security_group" "opengis" {
  name        = "${var.project_name}-sg"
  description = "OpenGIS platform security group"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "SSH from admin IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.admin_cidr]
    }
  }

  ingress {
    description = "HTTP from admin IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "HTTPS from admin IP, reserved for later Caddy HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "Allow outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}
