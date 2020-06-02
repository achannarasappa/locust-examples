provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "apartment-listings"

  cidr = "10.0.0.0/16"

  azs             = ["us-east-1c", "us-east-1d"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  public_subnet_tags = {
    Name = "apartment-listings-public"
  }
  private_subnet_tags = {
    Name = "apartment-listings-private"
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "apartment-listings-vpc"
  }

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true
  enable_dns_hostnames                   = true
  enable_dns_support                     = true
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "apartment-listings-postgres"

  engine            = "postgres"
  engine_version    = "10.10"
  instance_class    = "db.t3.micro"
  allocated_storage = 5
  storage_encrypted = false

  name     = var.postgres_database
  username = var.postgres_user
  password = var.postgres_password
  port     = var.postgres_port

  publicly_accessible = true

  vpc_security_group_ids = [module.locust.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 0
  family                  = "postgres10"
  major_engine_version    = "10.10"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  subnet_ids          = module.vpc.public_subnets
  deletion_protection = false
}

module "locust" {
  source             = "github.com/achannarasappa/locust-aws-terraform"
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets
  vpc_id             = module.vpc.vpc_id
}

resource "aws_lambda_function" "apartment_listings_crawler" {
  function_name    = "apartment-listings"
  filename         = var.package
  source_code_hash = filebase64sha256(var.package)

  handler = "src/handler.start"
  runtime = "nodejs10.x"
  timeout = 60

  role = module.locust.iam_role_arn

  vpc_config {
    subnet_ids         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
    security_group_ids = [module.locust.security_group_id]
  }

  environment {
    variables = {
      CHROME_HOST       = module.locust.chrome_hostname
      REDIS_HOST        = module.locust.redis_hostname
      POSTGRES_HOST     = module.db.this_db_instance_address
      POSTGRES_USER     = var.postgres_user
      POSTGRES_PASSWORD = var.postgres_password
      POSTGRES_DATABASE = var.postgres_database
      POSTGRES_PORT     = var.postgres_port
    }
  }

}

resource "aws_lambda_permission" "apartment_listings_crawler" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.apartment_listings_crawler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.apartment_listings_crawler.arn
}

resource "aws_cloudwatch_event_rule" "apartment_listings_crawler" {
  name        = "apartment_listings_crawler"
  description = "Crawls apartment listings on a schedule"

  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "apartment_listings_crawler" {
  rule = aws_cloudwatch_event_rule.apartment_listings_crawler.name
  arn  = aws_lambda_function.apartment_listings_crawler.arn
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group_rule" "postgres_remote_connection" {
  type        = "ingress"
  from_port   = tonumber(var.postgres_port)
  to_port     = tonumber(var.postgres_port)
  protocol    = "-1"
  cidr_blocks = ["${chomp(data.http.myip.body)}/32"]

  security_group_id = module.locust.security_group_id
}

resource "null_resource" "db_setup" {
  provisioner "local-exec" {
    command = "PGPASSWORD=${var.postgres_password} psql -h ${module.db.this_db_instance_address} -p ${var.postgres_port} -f ../db/schema/setup.sql ${var.postgres_database} ${var.postgres_user}"
  }
}
