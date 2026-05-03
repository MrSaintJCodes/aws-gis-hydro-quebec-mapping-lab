output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.opengis.id
}

output "public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.opengis.public_ip
}

output "public_dns" {
  description = "EC2 public DNS"
  value       = aws_instance.opengis.public_dns
}

output "ssh_command" {
  description = "SSH command if key_name is configured"
  value       = var.key_name == "" ? "No key_name configured. Use SSM Session Manager." : "ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@${aws_instance.opengis.public_dns}"
}

output "ssm_command" {
  description = "SSM Session Manager command"
  value       = "aws ssm start-session --target ${aws_instance.opengis.id} --region ${var.region}"
}

output "web_map_url" {
  description = "MapLibre demo frontend"
  value       = "http://${aws_instance.opengis.public_dns}/"
}

output "geoserver_url" {
  description = "GeoServer URL"
  value       = "http://${aws_instance.opengis.public_dns}/geoserver"
}

output "pg_tileserv_url" {
  description = "pg_tileserv URL"
  value       = "http://${aws_instance.opengis.public_dns}/tiles"
}

output "pgadmin_url" {
  description = "pgAdmin URL"
  value       = var.enable_pgadmin ? "http://${aws_instance.opengis.public_dns}/pgadmin" : "pgAdmin disabled"
}

output "postgis_connection_from_instance" {
  description = "PostGIS connection command from the EC2 instance"
  value       = "docker exec -it opengis-postgis psql -U ${var.postgres_user} -d ${var.postgres_db}"
}

output "postgis_password" {
  description = "Generated PostGIS password"
  value       = random_password.postgis.result
  sensitive   = true
}

output "geoserver_admin_username" {
  description = "GeoServer admin username"
  value       = "admin"
}

output "geoserver_admin_password" {
  description = "Generated GeoServer admin password"
  value       = random_password.geoserver_admin.result
  sensitive   = true
}

output "pgadmin_email" {
  description = "pgAdmin login email"
  value       = var.pgadmin_email
}

output "pgadmin_password" {
  description = "Generated pgAdmin password"
  value       = random_password.pgadmin.result
  sensitive   = true
}
