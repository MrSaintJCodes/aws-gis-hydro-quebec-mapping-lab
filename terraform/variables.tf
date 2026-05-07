variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix."
  type        = string
  default     = "opengis-ha"
}

variable "azs" {
  description = "Availability zones to use. Provide exactly two for this HA lab."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.70.0.0/16"
}

variable "enable_ssh" {
  description = "Whether to allow SSH access to the EC2 instance."
  type        = bool
  default     = true
}

variable "admin_cidr" {
  description = "Your public IP in CIDR format for ALB access, for example 1.2.3.4/32."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for app servers."
  type        = string
  default     = "t3.small"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "root_volume_size" {
  type    = number
  default = 30
}

variable "postgres_db" {
  type    = string
  default = "gis"
}

variable "postgres_user" {
  type    = string
  default = "gisuser"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ RDS. More production-like but costs more."
  type        = bool
  default     = false
}

variable "enable_pgadmin" {
  type    = bool
  default = true
}

variable "pgadmin_email" {
  type    = string
  default = "admin@example.com"
}

variable "geoserver_image" {
  type    = string
  default = "docker.osgeo.org/geoserver:3.0.x"
}

variable "postgis_image" {
  description = "No longer used in HA mode, kept for compatibility."
  type        = string
  default     = "postgis/postgis:16-3.4"
}

variable "enable_bastion" {
  description = "Whether to create a bastion host for troubleshooting."
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion host."
  type        = string
  default     = "t3.micro"
}