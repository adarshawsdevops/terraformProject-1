resource "aws_vpc" "myVPC" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.myVPC.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.myVPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myVPC.id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myVPC.id

   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
   subnet_id = aws_subnet.sub1.id
   route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
   subnet_id = aws_subnet.sub2.id
   route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name        = "web"
  vpc_id      = aws_vpc.myVPC.id
  
  tags = {
    Name = "Web-sg"
  }
}

resource "aws_security_group_rule" "HTTP_from_VPC" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.webSg.id
}

resource "aws_security_group_rule" "SSH_from_VPC" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.webSg.id
}

resource "aws_security_group_rule" "allow_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"] 
  security_group_id = aws_security_group.webSg.id
}

resource "aws_s3_bucket" "example" {
  bucket = "adarshterraformproject"
}

resource "aws_instance" "webserver1" {
 ami = "ami-09040d770ffe2224f" 
 instance_type = "t2.micro"
 vpc_security_group_ids = [aws_security_group.webSg.id]
 subnet_id = aws_subnet.sub1.id
 user_data = base64encode(file("userdata.sh")) 
}

resource "aws_instance" "webserver2" {
 ami = "ami-09040d770ffe2224f" 
 instance_type = "t2.micro"
 vpc_security_group_ids = [aws_security_group.webSg.id]
 subnet_id = aws_subnet.sub2.id
 user_data = base64encode(file("userdata1.sh")) 
}

#create alb
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.webSg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "web"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}