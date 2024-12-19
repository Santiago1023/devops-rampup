
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

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  # vpc = true
  domain = "vpc"
  tags = {
    Name = "${var.my_project_name}-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "ng" {
  allocation_id = aws_eip.nat_eip.id # Vincula el Elastic IP
  subnet_id     = aws_subnet.public-subnet1.id
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



# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  name_prefix = "${var.my_project_name}-lb-sg"
  vpc_id      = aws_vpc.vpc.id

  # Allow incoming traffic to the Load Balancer (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public access
  }

  # Allow outbound traffic to instances on the frontend port (3030)
  egress {
    from_port   = 3030
    to_port     = 3030
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block] # Comunicación dentro de la VPC
  }

  tags = {
    Name = "${var.my_project_name}-lb-sg"
  }
}


# Security Group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.my_project_name}-ec2-sg"
  vpc_id      = aws_vpc.vpc.id

  # Allow traffic from Load Balancer to the frontend (port 3030)
  ingress {
    from_port       = 3030
    to_port         = 3030
    protocol        = "tcp"
    # cidr_blocks     = [aws_vpc.vpc.cidr_block] # Communication within the VPC
    security_groups = [aws_security_group.lb_sg.id]
  }

  # Allow internal communication between frontend and backend (port 3000)
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks     = [aws_vpc.vpc.cidr_block] # Communication within the VPC
  }

  # Allow outbound traffic to anywhere (to communicate with databases or internet if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.my_project_name}-ec2-sg"
  }
}



# Load Balancer Target Group
resource "aws_lb_target_group" "tg" {
  name     = "${var.my_project_name}-tg"
  port     = 3030                    # Puerto del frontend
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    enabled             = true
    path                = "/"        # Ruta para el health check
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    protocol            = "HTTP"
  }

  tags = {
    Name = "${var.my_project_name}-tg"
  }
}

# Load Balancer (Application Load Balancer)
resource "aws_lb" "elb" {
  name               = "${var.my_project_name}-elb"
  internal           = false            # Public LB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public-subnet1.id, aws_subnet.public-subnet2.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.my_project_name}-elb"
  }
}

# Listener for HTTP (Port 80 -> 3030)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.elb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.instance.id
  port             = 3030
}


# instance 
resource "aws_instance" "instance" {
  subnet_id = aws_subnet.private-subnet1.id
  ami           = "ami-01816d07b1128cd2d"   # ami amazon linux en la free tier us-east-1
  instance_type = "t2.micro"    # t2.micro for free tier
  user_data     = file("init-script.sh")    # script to install all the dependencies and run the apps
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]   # security group

  tags = {
    Name = "${var.my_project_name}-instance"
  }
}



resource "aws_security_group" "rds_sg" {
  name = "${var.my_project_name}-rds-sg"
  description = "Security group for rds and ec2 communication"
  vpc_id = aws_vpc.vpc.id

  # inbound rule that allows traffic from the EC2 security group, through TCP port 3306, which is the MySQL port
  ingress {
    description = "Allow MySQL traffic from only the ec2 sg"
    from_port = "3306"
    to_port = "3306"
    protocol = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  tags = {
    Name = "${var.my_project_name}-rds-sg"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "${var.my_project_name}-rds-subnet-group"
  description = "DB subnet group"
  # subnet_ids = [aws_subnet.private-subnet2.id]
  subnet_ids  = [aws_subnet.private-subnet1.id, aws_subnet.private-subnet2.id]
}

resource "aws_db_instance" "db_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"  # General Purpose SSD
  engine               = "mysql"
  engine_version       = "8.0"  
  instance_class       = "db.t3.micro"  # Free Tier
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az             = false  # Solo una zona de disponibilidad
  publicly_accessible  = false  # No debe ser accesible desde Internet
  username             = var.db_username
  password             = var.db_password
  db_name              = var.db_name
  skip_final_snapshot  = true

  tags = {
     Name = "${var.my_project_name}-db"
  }
}


resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.my_project_name}-bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = aws_vpc.vpc.id

  ingress {
      description      = "Allow SSH from specific IP"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"] # Tu IP pública para acceso restringido
    }

  egress {
      description      = "Allow all outbound traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami           = "ami-01816d07b1128cd2d"   # ami amazon linux en la free tier us-east-1
  instance_type = "t2.micro"    # t2.micro for free tier
  subnet_id     = aws_subnet.public-subnet1.id      # Subnet pública donde irá el bastion host
  key_name      = var.key_name
  # security_groups = [aws_security_group.bastion_sg.name]
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]   # security group


  tags = {
    Name = "${var.my_project_name}-bastion-instance"
  }
}
# Asigna un Elastic IP a la instancia Bastion Host
resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  domain = "vpc"
  tags = {
    Name = "${var.my_project_name}-bastion-eip"
  }
}
