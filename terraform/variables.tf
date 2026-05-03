variable "region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "project_name" {
  description = "Project name prefix. Use lowercase letters, numbers, and hyphens."
  type        = string
  default     = "opengis-lab"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR format, for example 1.2.3.4/32"
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name. Leave empty to use SSM Session Manager only."
  type        = string
  default     = ""
}

variable "enable_ssh" {
  description = "Whether to open SSH from admin_cidr."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is cheapest/free-tier friendly but tight for GeoServer. t3.small is smoother."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 20
}

variable "postgres_db" {
  description = "PostGIS database name."
  type        = string
  default     = "gis"
}

variable "postgres_user" {
  description = "PostGIS database user."
  type        = string
  default     = "gisuser"
}

variable "pgadmin_email" {
  description = "pgAdmin login email."
  type        = string
  default     = "admin@example.com"
}

variable "geoserver_image" {
  description = "GeoServer Docker image."
  type        = string
  default     = "docker.osgeo.org/geoserver:3.0.x"
}

variable "postgis_image" {
  description = "PostGIS Docker image."
  type        = string
  default     = "postgis/postgis:16-3.4"
}

variable "enable_pgadmin" {
  description = "Deploy pgAdmin container."
  type        = bool
  default     = true
}
