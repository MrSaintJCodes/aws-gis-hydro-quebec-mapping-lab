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
  length           = 24
  special          = false
}

resource "random_password" "geoserver_admin" {
  length           = 20
  special          = false
}

resource "random_password" "pgadmin" {
  length           = 24
  special          = false
}
