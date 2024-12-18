
provider "aws" {
#   region = "us-east-1"
  region = var.aws_region
}

resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr_block # /16
  instance_tenancy = "default"
  tags = {
    Name = "${var.my_project_name}-vpc" # configure our own name 
  }
}

#public-subnet1 creation
resource "aws_subnet" "public-subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[0]
#   map_public_ip_on_launch = "false"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "${var.my_project_name}-public-subnet1" 
  }
}
#public-subnet2 creation
resource "aws_subnet" "public-subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[1]
#   map_public_ip_on_launch = "false"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "${var.my_project_name}-public-subnet2" 
  }
}
#private-subnet1 creation
resource "aws_subnet" "private-subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[0]
  availability_zone       = "us-east-1a"
  tags = {
    Name = "${var.my_project_name}-private-subnet1" 
  }
}
#private-subnet2 creation
resource "aws_subnet" "private-subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.private_subnet_cidr_blocks[1]
  availability_zone       = "us-east-1b"
  tags = {
    Name = "${var.my_project_name}-private-subnet2" 
  }
}

# internet gateway creation
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
}

# Route table creation to internet gateway
resource "aws_route_table" "route-ig" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  tags = {
    Name = "route to internet"
  }
}
#route 1 association
resource "aws_route_table_association" "route1" {
  # Allows public-subnet1 connect with internet  
  subnet_id      = aws_subnet.public-subnet1.id
  route_table_id = aws_route_table.route-ig.id
}
#route 2 association
resource "aws_route_table_association" "route2" {
  # Allows public-subnet2 connect with internet  
  subnet_id      = aws_subnet.public-subnet2.id
  route_table_id = aws_route_table.route-ig.id
}


resource "aws_nat_gateway" "ng" {
  subnet_id     = aws_subnet.public-subnet1
  tags = {
    Name = "${var.my_project_name}-nat-gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.ig]
}

# Route table creation to nat gateway
resource "aws_route_table" "route-ng" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ng.id
  }
  tags = {
    Name = "private route to internet"
  }
}
#route 1 association
resource "aws_route_table_association" "private-route1" {
  # Allows private-subnet1 connect with internet  
  subnet_id      = aws_subnet.private-subnet1.id
  route_table_id = aws_route_table.route-ng.id
}
#route 2 association
resource "aws_route_table_association" "private-route2" {
  # Allows private-subnet2 connect with internet  
  subnet_id      = aws_subnet.private-subnet2.id
  route_table_id = aws_route_table.route-ng.id
}



# instance 
resource "aws_instance" "web-instance" {
  ami           = "ami-01816d07b1128cd2d"   # ami amazon linux en la free tier us-east-1
  instance_type = "t2.micro"    # t2.micro for free tier
  user_data     = file("init-script.sh")    # script to install all the dependencies and run the apps
  vpc_security_group_ids = [aws_security_group.web-sg.id]   # security group

  tags = {
    Name = "${var.my_project_name}-instance"
  }
}

resource "aws_security_group" "web-sg" {
    tags = {
        Name = "${var.my_project_name}-sg"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}