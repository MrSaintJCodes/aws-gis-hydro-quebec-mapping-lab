resource "aws_db_subnet_group" "postgis" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}

resource "aws_db_instance" "postgis" {
  identifier = "${local.name}-postgis"

  engine         = "postgres"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = var.postgres_db
  username = var.postgres_user
  password = random_password.postgis.result

  db_subnet_group_name   = aws_db_subnet_group.postgis.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = var.db_multi_az

  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  apply_immediately = true

  tags = {
    Name = "${local.name}-postgis"
  }
}