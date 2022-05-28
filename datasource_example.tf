resource "aws_instance" "ec2_test" {
  ami                         = data.aws_ami.app_ami.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = "mykeypair"
  vpc_security_group_ids      = [aws_security_group.avis.id]
  tags = {
    Name = var.name
  }

}

resource "aws_security_group" "avis" {
  name        = "avis"
  description = "SG group for my instance"
  vpc_id      = data.aws_vpc.vpc-check.id

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    description = "allow port 22 to all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow 80 port"
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all ip and ports outboun"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }


}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}
variable "name" {}


resource "tls_private_key" "mykey" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "mykeypair" {
  public_key = tls_private_key.mykey.public_key_openssh
  key_name   = "mykeypair"
}

resource "local_file" "myec2key" {
  filename = "myec2key"
  content  = tls_private_key.mykey.private_key_pem
}

data "aws_vpc" "vpc-check" {
  default = true

}


resource "null_resource" "install" {
  depends_on = [aws_key_pair.mykeypair, aws_instance.ec2_test]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.mykey.private_key_pem
      host        = aws_instance.ec2_test.public_ip
    }
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo systemctl enable httpd",
      "sudo service httpd start",
      "sudo yum install -y httpd",
      "echo '<h1>Welcome  ! AWS Infra created using Terraform in ap-south-1 Region</h1>' | sudo tee /var/www/html/index.html"
    ]

  }

}

output "public_ip" {
  value = aws_instance.ec2_test.public_ip
}



