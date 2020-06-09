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

  vpc_tags = {
    Name = "apartment-listings-vpc"
  }

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
}

resource "aws_rds_cluster" "apartment_listings_aurora" {
  cluster_identifier      = "apartment-listings-aurora"
  engine                  = "aurora-postgresql"
  engine_mode             = "serverless"
  db_subnet_group_name    = aws_db_subnet_group.apartment_listings_aurora.name
  database_name           = var.postgres_database
  master_username         = var.postgres_user
  master_password         = var.postgres_password
  backup_retention_period = 1
  preferred_backup_window = "03:00-06:00"
  vpc_security_group_ids  = [aws_security_group.setup.id, module.locust.security_group_id]

  scaling_configuration {
    max_capacity = 4
  }

  apply_immediately   = true
  skip_final_snapshot = true
}

resource "aws_db_subnet_group" "apartment_listings_aurora" {
  name       = "apartment_listings_aurora"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "setup" {
  name   = "setup"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "SSH to VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  ingress {
    protocol  = "-1"
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "setup" {
  ami           = "ami-04b9e92b5572fa0d1"
  instance_type = "t2.micro"

  vpc_security_group_ids      = [aws_security_group.setup.id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = "ani" # replace with a public key in AWS

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa") # replace with the location of corresponding private key above
    host        = aws_instance.setup.public_ip
  }

  provisioner "file" {
    source      = "../db/schema/setup.sql"
    destination = "/home/ubuntu/setup.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update && sudo apt-get install postgresql-client -y",
      "PGPASSWORD=${var.postgres_password} psql -h ${aws_rds_cluster.apartment_listings_aurora.endpoint} -p ${var.postgres_port} -f setup.sql ${var.postgres_database} ${var.postgres_user}",
    ]
  }
}

output "instance_ip_addr" {
  value       = aws_instance.setup.public_ip
  description = "The public IP address of the setup server instance."
}

module "locust" {
  source             = "github.com/achannarasappa/locust-aws-terraform"
  private_subnet_ids = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id
}

resource "aws_lambda_function" "apartment_listings_crawler" {
  function_name    = "apartment-listings"
  filename         = var.package
  source_code_hash = filebase64sha256(var.package)

  handler = "src/handler.start"
  runtime = "nodejs10.x"
  timeout = 30

  role = module.locust.iam_role_arn

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [module.locust.security_group_id]
  }

  environment {
    variables = {
      CHROME_HOST       = module.locust.chrome_hostname
      REDIS_HOST        = module.locust.redis_hostname
      POSTGRES_HOST     = aws_rds_cluster.apartment_listings_aurora.endpoint
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
