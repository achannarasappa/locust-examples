output "private_redis_endpoint" {
  value = module.locust.redis_hostname
}

output "private_aurora_endpoint" {
  value = aws_rds_cluster.apartment_listings_aurora.endpoint
}

output "bastion_host" {
  value = aws_instance.setup.public_ip
}
