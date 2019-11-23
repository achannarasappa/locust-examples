provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "locust"

  cidr = "10.0.0.0/16"

  azs             = ["us-east-1c", "us-east-1d"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    Name = "locust-public"
  }
  private_subnet_tags = {
    Name = "locust-private"
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "locust-vpc"
  }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "vacation-listings-postgres"

  engine            = "postgres"
  engine_version    = "10.10"
  instance_class    = "db.t3.micro"
  allocated_storage = 5
  storage_encrypted = false

  name     = var.postgres_database
  username = var.postgres_user
  password = var.postgres_password
  port     = "5432"

  vpc_security_group_ids = ["${module.locust.security_group_id}"]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 0
  family                  = "postgres10"
  major_engine_version    = "10.10"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  subnet_ids          = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  deletion_protection = false
}

module "locust" {
  source             = "github.com/achannarasappa/locust-aws-terraform"
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets
  vpc_id             = module.vpc.vpc_id
}

resource "aws_lambda_function" "locust_job" {
  function_name    = "vacation-listings"
  filename         = var.package
  source_code_hash = filebase64sha256(var.package)

  handler = "src/handler.start"
  runtime = "nodejs10.x"
  timeout = 15

  role = "${module.locust.iam_role_arn}"

  vpc_config {
    subnet_ids         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
    security_group_ids = ["${module.locust.security_group_id}"]
  }

  environment {
    variables = {
      CHROME_HOST       = "${module.locust.chrome_hostname}"
      REDIS_HOST        = "${module.locust.redis_hostname}"
      POSTGRES_HOST     = "${module.db.this_db_instance_endpoint}"
      POSTGRES_USER     = "${var.postgres_user}"
      POSTGRES_PASSWORD = "${var.postgres_password}"
      POSTGRES_DATABASE = "${var.postgres_database}"
    }
  }

}
