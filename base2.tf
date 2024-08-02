# Definición de la región por defecto y otros valores comunes
variable "region" {
  description = "AWS region"
  default     = "eu-west-1"
}

variable "project" {
  description = "Nombre del proyecto"
  default     = "GenAI"
}

variable "eid" {
  description = "Correo electrónico del usuario"
  default     = "l.saavedra.palacios@accenture.com"
}

variable "environment" {
  description = "Entorno de despliegue"
  default     = "dev"
}

locals {
  common_tags = {
    Proyecto         = var.project
    Centro_de_Coste  = "modificar antes de desplegar"
    environment      = var.environment
    eid              = var.eid
    BackupPlan       = var.environment == "prod" ? "gold" : var.environment == "pre" || var.environment == "stg" ? "silver" : "bronze"
  }
}

# Configuración del provider AWS
provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}

# Configuración del backend remoto para Terraform
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "juanmi"
    workspaces {
      name = "test_inicial_terraform"
    }
  }
}

# Creación de un bucket S3
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.0.0"

  bucket = "s3---"
  acl    = "private"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "aws:kms"
      }
    }
  }

  force_destroy = true
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  tags = local.common_tags
}

output "s3_bucket_id" {
  value = module.s3_bucket.s3_bucket_id
}

# Creación de una instancia EC2 de tipo Linux
module "linux_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.4.0"

  name = "ec2---01"

  ami                    = data.aws_ami.ubuntu_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.instance_key.key_name
  subnet_id              = data.aws_subnet.internal_subnet_tier2["a"].id
  vpc_security_group_ids = [module.linux_sg.sg-id]

  root_block_device = [{
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }]

  ebs_block_device = [
    {
      device_name           = "/dev/xvdba"
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    },
    {
      device_name           = "/dev/xvdbb"
      volume_size           = 50
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "ec2---01"
    }
  )

  create_iam_instance_profile = true
  iam_role_description = "IAM role for AWS Systems Manager"
  iam_role_policies = {
    "AmazonSSMManagedInstanceCore" = ""
  }
}

# Creación de Security Group para la instancia EC2
module "linux_sg" {
  source = "app.terraform.io/juanmi/grupoawselzmodsg/aws"
  version = "0.0.1"

  sg_name        = "ec2---sg"
  sg_description = "Security group for Linux instance with custom ingress rules"
  vpc_id         = data.aws_vpc.comms_dmz_vpc.id

  rules = {
    rpl-9100-monitorizacion = {
      from_port   = 9100
      to_port     = 9100
      protocol    = "tcp"
      source      = data.aws_ec2_managed_prefix_list.acceso_monitorizacion.id
      type        = "ingress"
    },
    rpl-ssh-bastion = {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      source      = data.aws_ec2_managed_prefix_list.acceso_bastion.id
      type        = "ingress"
    },
    rci-custom-3000 = {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      source      = "10.0.1.0/24"
      type        = "ingress"
    },
    rci-egress = {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      source      = "10.0.0.0/8"
      type        = "egress"
    }
  }
}

# Creación de un par de claves para la instancia EC2
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "instance_key" {
  key_name   = "instance-key--"
  public_key = tls_private_key.instance_key.public_key_openssh
}

output "private_key" {
  description = "La clave privada de la instancia EC2"
  value       = tls_private_key.instance_key.private_key_pem
  sensitive   = true
}

# Creación de una instancia RDS
module "rds_instance" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.1.0"

  identifier            = "rds---01"
  engine                = "postgres"
  engine_version        = "14.0"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  port                  = 5432

  multi_az             = false
  maintenance_window   = "Mon:00:00-Mon:03:00"
  backup_window        = "03:00-06:00"
  storage_encrypted    = true
  create_db_subnet_group = true
  subnet_ids           = [data.aws_subnet.internal_subnet_tier3["a"].id, data.aws_subnet.internal_subnet_tier3["b"].id]

  vpc_security_group_ids = [module.rds_sg.sg-id]

  tags = merge(
    local.common_tags,
    {
      Name = "rds---01"
    }
  )

  family = "postgres14" # Agrega el argumento "family" al recurso aws_db_parameter_group
}

# Creación de Security Group para la instancia RDS
module "rds_sg" {
  source = "app.terraform.io/juanmi/grupoawselzmodsg/aws"
  version = "0.0.1"

  sg_name        = "rds---sg"
  sg_description = "Security group for RDS instance with custom ingress rules"
  vpc_id         = data.aws_vpc.comms_dmz_vpc.id

  rules = {
    rsg-5432-linux-ec2 = {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      type        = "ingress"
      source      = module.linux_sg.sg-id
    },
    rpl-acceso-bbdd = {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      source      = data.aws_ec2_managed_prefix_list.acceso_bbdd.id
      type        = "ingress"
    },
    rci-egress = {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      source      = "10.0.0.0/8"
      type        = "egress"
    }
  }
}

# Generación de sufijo aleatorio para el nombre del bucket S3
resource "random_pet" "bucket_suffix" {
  length    = 3
  separator = "-"
}
