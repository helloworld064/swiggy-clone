
# ----------------------
# 1. Custom VPC
# ----------------------
resource "aws_vpc" "custom_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "custom-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "custom-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "custom-public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "custom-public-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ----------------------
# 2. Security Group (allow all)
# ----------------------
resource "aws_security_group" "allow_all" {
  name        = "allow-all-sg"
  description = "Allow all traffic (not secure for prod)"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-all"
  }
}

# ----------------------
# 3. (Optional) Key Pair
# ----------------------
resource "aws_key_pair" "deployer_key" {
  key_name   = "terraform-key"
  public_key = file("terraform-key.pub") # Update path to your pub key
}

# ----------------------
# 4. EC2 Instance
# ----------------------
resource "aws_instance" "web" {
  ami                         = "ami-042b4708b1d05f512" # update if needed
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  key_name                    = aws_key_pair.deployer_key.key_name
  associate_public_ip_address = true
  user_data                   = file("script.sh") # your Jenkins install script

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "jenkins-ec2"
  }
}

