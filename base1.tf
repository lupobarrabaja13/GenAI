#Prefix list para security group
data "aws_ec2_managed_prefix_list" "acceso_bastion" {
  name = "acceso_bastion"
}
 
data "aws_ec2_managed_prefix_list" "acceso_monitorizacion" {
  name = "acceso_monitorizacion"
}
data "aws_ec2_managed_prefix_list" "acceso_bbdd" {
  name = "acceso_bbdd"
}


# VPC
data "aws_vpc" "comms_dmz_vpc" {
  tags = {
    Name = "vpc-coms-dmz-prod"
  }
}

# CAPA I
data "aws_subnets" "internal_subnets_tier1" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.comms_dmz_vpc.id]
  }
  tags = {
    Name = "*internal-subnets-tier*"
  }
}
 
data "aws_subnet" "internal_subnet_tier1" {
  for_each = toset(["a", "b"])
  vpc_id   = data.aws_vpc.comms_dmz_vpc.id
 
  filter {
    name   = "tag:Name"
    values = ["*internal-subnets-tier-1*"]
  }
 
  filter {
    name   = "availability-zone"
    values = ["${var.region}${each.key}"]
  }
}

# CAPA II
data "aws_subnets" "internal_subnets_tier2" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.comms_dmz_vpc.id]
  }
  tags = {
    Name = "*internal-subnets-tier-2*"
  }
}
 
data "aws_subnet" "internal_subnet_tier2" {
  for_each = toset(["a", "b"])
  vpc_id   = data.aws_vpc.comms_dmz_vpc.id
 
  filter {
    name   = "tag:Name"
    values = ["*internal-subnets-tier-2*"]
  }
 
  filter {
    name   = "availability-zone"
    values = ["${var.region}${each.key}"]
  }
}

# CAPA III
data "aws_subnets" "internal_subnets_tier3" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.comms_dmz_vpc.id]
  }
  tags = {
    Name = "*internal-subnets-tier-3*"
  }
}
 
data "aws_subnet" "internal_subnet_tier3" {
  for_each = toset(["a", "b"])
  vpc_id   = data.aws_vpc.comms_dmz_vpc.id
 
  filter {
    name   = "tag:Name"
    values = ["*internal-subnets-tier-3*"]
  }
 
  filter {
    name   = "availability-zone"
    values = ["${var.region}${each.key}"]
  }
}

# CAPA PUBLICA
data "aws_subnets" "internal_subnets_tier_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.comms_dmz_vpc.id]
  }
  tags = {
    Name = "*prod-public-tier*"
  }
}
 
data "aws_subnet" "internal_subnet_tier_public" {
  for_each = toset(["a", "b"])
  vpc_id   = data.aws_vpc.comms_dmz_vpc.id
 
  filter {
    name   = "tag:Name"
    values = ["*prod-public-tier*"]
  }
 
  filter {
    name   = "availability-zone"
    values = ["${var.region}${each.key}"]
  }
}

# AMIS INSTANCIAS
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "windows_ami" {
    most_recent = true     
    filter {
           name   = "name"
           values = ["Windows_Server-2019-English-Full-Base-*"]  
      }     
    filter {
           name   = "virtualization-type"
           values = ["hvm"]  
      }
    owners = ["801119661308"] # Canonical

}
