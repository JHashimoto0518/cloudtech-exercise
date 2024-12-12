terraform {
  required_version = "1.10.1"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.80.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# ① VPCの作成
resource "aws_vpc" "reservation_vpc" {
  cidr_block = "10.0.0.0/21"
  tags = {
    Name = "reservation-vpc"
  }
}

# ② web-subnet-01を作成
resource "aws_subnet" "web_subnet_01" {
  vpc_id = aws_vpc.reservation_vpc.id
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "web-subnet-01"
  }
}

# ルートテーブルとしてapi-routetable を作成し、api-subnet-01 に関連付けする
resource "aws_route_table" "web_routetable" {
  vpc_id = aws_vpc.reservation_vpc.id
  tags = {
    Name = "web-routetable"
  }
}

resource "aws_route_table_association" "web_routetable_association" {
  subnet_id = aws_subnet.web_subnet_01.id
  route_table_id = aws_route_table.web_routetable.id
}

# ③ api-subnet-01を作成
resource "aws_subnet" "api_subnet_01" {
  vpc_id = aws_vpc.reservation_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "api-subnet-01"
  }
}

# ルートテーブルとしてapi-routetable を作成し、api-subnet-01 に関連付けする
resource "aws_route_table" "api_routetable" {
  vpc_id = aws_vpc.reservation_vpc.id
  tags = {
    Name = "api-routetable"
  }
}

resource "aws_route_table_association" "api_routetable_association" {
  subnet_id = aws_subnet.api_subnet_01.id
  route_table_id = aws_route_table.api_routetable.id
}   

# ④ インターネットゲートウェイの作成
resource "aws_internet_gateway" "reservation_ig" {
  vpc_id = aws_vpc.reservation_vpc.id
  tags = {
    Name = "reservation-ig"
  }
}

# web-routetable およびapi-routetable に設定する
resource "aws_route" "web-routetable-route" {
  route_table_id = aws_route_table.web_routetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.reservation_ig.id
}

resource "aws_route" "api_routetable_route" {
  route_table_id = aws_route_table.api_routetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.reservation_ig.id
}

# セキュリティグループの作成
# APIサーバおよびWebサーバに対するインバウンド通信は、「すべてのHTTP通信」のみとする
# ただし、EC2インスタンスコネクト用のSSH通信は許可する
resource "aws_security_group" "api_security_group" {
  name = "api-security-group"
  vpc_id = aws_vpc.reservation_vpc.id
}

resource "aws_security_group_rule" "api_security_group_rule_http" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.api_security_group.id
}

data "aws_region" "current" {}

data "aws_ec2_managed_prefix_list" "ec2_instance_connect_prefix_list" {
  name = "com.amazonaws.${data.aws_region.current.name}.ec2-instance-connect"
}

resource "aws_security_group_rule" "api_security_group_rule_ssh" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  prefix_list_ids = [data.aws_ec2_managed_prefix_list.ec2_instance_connect_prefix_list.id]
  security_group_id = aws_security_group.api_security_group.id
}

resource "aws_security_group" "web_security_group" {
  name = "web-security-group"
  vpc_id = aws_vpc.reservation_vpc.id
}

resource "aws_security_group_rule" "web_security_group_rule" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_security_group.id
}

# ⑤⑥の準備 最新のAmazon Linux 2023 AMIを参照
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# TODO: セットアップされていない
# [ec2-user@ip-10-0-1-15 ~]$ sudo su
# [root@ip-10-0-1-15 ec2-user]# cat /etc/systemd/system/goserver.service
# cat: /etc/systemd/system/goserver.service: No such file or directory
# [root@ip-10-0-1-15 ec2-user]# cat /etc/nginx/nginx.conf
# cat: /etc/nginx/nginx.conf: No such file or directory

resource "aws_instance" "api_server_01" {
  ami = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t2.micro"
  subnet_id = aws_subnet.api_subnet_01.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.api_security_group.id]
  user_data = file("api-server-user-data.sh")
  tags = {
    Name = "api-server-01"
  }
  # NOTE: aws_ssm_parameter.al2023_ami の値が変わってもリプレースしない
  lifecycle {
    ignore_changes = [ami]
  }
}

# ⑥ Webサーバの構築
# resource "aws_instance" "web_server_01" {
#   ami = data.aws_ssm_parameter.al2023_ami.value
#   instance_type = "t2.micro"
#   subnet_id = aws_subnet.web_subnet_01.id
#   associate_public_ip_address = true
#   vpc_security_group_ids = [aws_security_group.web_security_group.id]
#   tags = {
#     Name = "web-server-01"
#   }
# }