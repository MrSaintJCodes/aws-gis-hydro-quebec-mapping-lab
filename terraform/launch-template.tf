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

resource "aws_launch_template" "opengis" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.main.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(templatefile("${path.module}/../templates/user-data-ha.sh.tftpl", {
    aws_region               = var.region
    artifact_bucket          = aws_s3_bucket.opengis_artifacts.id
    artifact_key             = aws_s3_object.opengis_app.key

    project_name             = var.project_name
    postgres_host            = aws_db_instance.postgis.address
    postgres_port            = 5432
    postgres_db              = var.postgres_db
    postgres_user            = var.postgres_user
    postgres_password        = random_password.postgis.result

    geoserver_admin_password = random_password.geoserver_admin.result
    pgadmin_email            = var.pgadmin_email
    pgadmin_password         = random_password.pgadmin.result

    geoserver_image          = var.geoserver_image
    postgis_image            = var.postgis_image
    enable_pgadmin           = var.enable_pgadmin

    efs_dns_name             = "${aws_efs_file_system.opengis.id}.efs.${var.region}.amazonaws.com"
    efs_mount_dir            = "/mnt/opengis-efs"
  }))

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.name}-app"
    }
  }

  depends_on = [
    aws_s3_object.opengis_app,
    aws_iam_role_policy_attachment.opengis_artifacts_read,
    aws_db_instance.postgis,
    aws_efs_mount_target.opengis
  ]
}