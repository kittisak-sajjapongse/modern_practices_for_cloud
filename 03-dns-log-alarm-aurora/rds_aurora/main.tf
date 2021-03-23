resource "aws_rds_cluster" "mysql_cluster" {
  cluster_identifier      = var.cluster-name
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.07.2"
  availability_zones      = ["us-east-1a"]
  database_name           = var.db-name
  master_username         = var.master-username
  master_password         = var.master-password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  vpc_security_group_ids  = var.security-group-ids

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_rds_cluster_instance" "mysql_cluster_instances" {
  count              = 2
  identifier         = "${var.cluster-name}-${count.index}"
  cluster_identifier = aws_rds_cluster.mysql_cluster.id
  instance_class     = "db.t3.small"
  engine             = aws_rds_cluster.mysql_cluster.engine
  engine_version     = aws_rds_cluster.mysql_cluster.engine_version

  lifecycle {
    ignore_changes = all
  }
}