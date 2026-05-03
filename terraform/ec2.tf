data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "opengis" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.opengis.id]
  key_name                    = aws_key_pair.main.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data_replace_on_change = true

  user_data = templatefile("../templates/user-data.sh.tftpl", {
    aws_region                   = var.region
    artifact_bucket              = aws_s3_bucket.opengis_artifacts.id
    artifact_key                 = aws_s3_object.opengis_app.key

    project_name                 = var.project_name
    postgres_db                  = var.postgres_db
    postgres_user                = var.postgres_user
    postgres_password            = random_password.postgis.result
    geoserver_admin_password     = random_password.geoserver_admin.result
    pgadmin_email                = var.pgadmin_email
    pgadmin_password             = random_password.pgadmin.result
    geoserver_image              = var.geoserver_image
    postgis_image                = var.postgis_image
    enable_pgadmin               = var.enable_pgadmin
  })

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }

  depends_on = [
    aws_s3_object.opengis_app,
    aws_iam_role_policy_attachment.opengis_artifacts_read
  ]
}
