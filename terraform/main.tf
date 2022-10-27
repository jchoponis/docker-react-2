terraform {
  backend "s3" {
    bucket = "docker-k8s-udemy-tf-state"
    key    = "terraform.state"
    region = "us-east-2"
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.36.1"
    }
  }
}
provider aws {
  region = "us-east-2"
}

# vpc and subnet basics
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
}

resource "aws_subnet" "main" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 4, 1)
  map_public_ip_on_launch         = true
  availability_zone = "us-east-2a"
}

resource "aws_subnet" "secondary" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 4, 2)
  map_public_ip_on_launch         = true
  availability_zone = "us-east-2b"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_default_route_table.main.id
}


output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id_1" {
    value = aws_subnet.main.id
}

output "subnet_id_2" {
    value = aws_subnet.secondary.id
}

# ---------------------------------------------------------------------------------------------------------------

#got some tips from https://automateinfra.com/2021/03/24/how-to-launch-aws-elastic-beanstalk-using-terraform/
resource "aws_elastic_beanstalk_application" "main" {
  name        = "docker-react-1"
  description = "docker react course project"
}

resource "aws_elastic_beanstalk_environment" "tfenvtest" {
  name                = "docker-react-1"
  application         = aws_elastic_beanstalk_application.main.name
  #get sol'n stack name with https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.docker
  solution_stack_name = "64bit Amazon Linux 2 v3.5.0 running Docker"

  #find settings here https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html#command-options-general-ec2vpc
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = aws_subnet.main.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = true
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = "t2.micro, t3.micro"
  }
  
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.allow_all_inside.id
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "REDIS_HOST"
    value     = aws_elasticache_replication_group.main.primary_endpoint_address
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "REDIS_PORT"
    value     = "6379"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PGUSER"
    value     = aws_db_instance.postgresql1.username
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PGPASSWORD"
    value     = aws_db_instance.postgresql1.password
  }
  
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PGHOST"
    #this endpoint for rds includes the port
    value     = split(":", aws_db_instance.postgresql1.endpoint)[0]
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PGDATABASE"
    value     = "fibvalues"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PGPORT"
    value     = "5432"
  }
}

output "ebs_endpoind_url" {
  value = aws_elastic_beanstalk_environment.tfenvtest.endpoint_url
}

#---------------------------------------------------------------------------------------------------------------

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.main.id, aws_subnet.secondary.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "postgresql1" {
  allocated_storage    = 10
  db_name              = "postgresql1"
  engine               = "postgres"
  engine_version       = "13.7"
  instance_class       = "db.t3.micro"
  username             = "pgadmin1"
  password             = "Tango-Apple-123"
  skip_final_snapshot  = true
  apply_immediately = true
  multi_az = false
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.allow_all_inside.id]
}

resource "aws_security_group" "allow_all_inside" {
  name        = "allow_internal_traffic"
  description = "allow internal traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    self = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

#---------------------------------------------------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis1" {
  name       = "tf-test-cache-subnet"
  subnet_ids = [aws_subnet.main.id, aws_subnet.secondary.id]
}

resource "aws_elasticache_replication_group" "main" {
  automatic_failover_enabled  = false
  replication_group_id        = "tf-rep-group-1"
  description                 = "example replication group"
  node_type                   = "cache.t3.micro"
  num_cache_clusters          = 1
  parameter_group_name        = "default.redis6.x"
  port                        = 6379
  engine = "redis"
  engine_version = "6.2"
  apply_immediately = true
  security_group_ids = [aws_security_group.allow_all_inside.id]
  subnet_group_name = aws_elasticache_subnet_group.redis1.name
  
  lifecycle {
    ignore_changes = [num_cache_clusters]
  }
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}