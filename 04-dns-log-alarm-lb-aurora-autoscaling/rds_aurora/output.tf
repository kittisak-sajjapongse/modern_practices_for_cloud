output "cluster-endpoint" {
  value = aws_rds_cluster.mysql_cluster.endpoint
}

output "read-endpoint" {
  value = aws_rds_cluster.mysql_cluster.reader_endpoint
}