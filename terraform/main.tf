terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }

    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "random_password" "postgis" {
  length  = 24
  special = false
}

resource "random_password" "geoserver_admin" {
  length  = 20
  special = false
}

resource "random_password" "pgadmin" {
  length  = 24
  special = false
}

locals {
  name = var.project_name

  public_subnet_cidrs      = [cidrsubnet(var.vpc_cidr, 8, 10), cidrsubnet(var.vpc_cidr, 8, 11)]
  private_app_subnet_cidrs = [cidrsubnet(var.vpc_cidr, 8, 20), cidrsubnet(var.vpc_cidr, 8, 21)]
  private_db_subnet_cidrs  = [cidrsubnet(var.vpc_cidr, 8, 30), cidrsubnet(var.vpc_cidr, 8, 31)]
}