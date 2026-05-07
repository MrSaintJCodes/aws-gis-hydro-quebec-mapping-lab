output "alb_dns_name" {
  value = aws_lb.opengis.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.postgis.address
}

output "efs_dns_name" {
  value = "${aws_efs_file_system.opengis.id}.efs.${var.region}.amazonaws.com"
}

output "geoserver_admin_password" {
  value     = random_password.geoserver_admin.result
  sensitive = true
}

output "postgres_password" {
  value     = random_password.postgis.result
  sensitive = true
}

output "pgadmin_password" {
  value     = random_password.pgadmin.result
  sensitive = true
}

output "bastion_public_ip" {
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
  description = "Public IP of the bastion host."
}