output "redis_host" {
  value = module.locust.redis_hostname
}
output "postgres_host" {
  value = module.db.this_db_instance_address
}

output "postgres_database" {
  value = module.db.this_db_instance_name
}

output "postgres_user" {
  value = module.db.this_db_instance_username
}
