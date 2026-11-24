data "aws_availability_zones" "primary" {
  provider = aws.primary
  state    = "available"
}

data "aws_availability_zones" "secondary" {
  provider = aws.secondary
  state    = "available"
}

# --- PRIMARY VPC (ap-south-1) ---
resource "aws_vpc" "primary" {
  provider             = aws.primary
  cidr_block           = var.primary_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-primary-vpc" }
}

resource "aws_internet_gateway" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  tags     = { Name = "${var.project_name}-primary-igw" }
}

resource "aws_subnet" "primary_public" {
  provider                = aws.primary
  count                   = 2
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = cidrsubnet(var.primary_vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.primary.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-primary-pub-${count.index + 1}" }
}

resource "aws_subnet" "primary_private" {
  provider          = aws.primary
  count             = 2
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(var.primary_vpc_cidr, 8, count.index + 11)
  availability_zone = data.aws_availability_zones.primary.names[count.index]
  tags              = { Name = "${var.project_name}-primary-priv-${count.index + 1}" }
}

resource "aws_eip" "primary_nat" {
  provider = aws.primary
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-primary-nat-eip" }
}

resource "aws_nat_gateway" "primary" {
  provider      = aws.primary
  allocation_id = aws_eip.primary_nat.id
  subnet_id     = aws_subnet.primary_public[0].id
  tags          = { Name = "${var.project_name}-primary-nat" }
  depends_on    = [aws_internet_gateway.primary]
}

resource "aws_route_table" "primary_public" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }
  tags = { Name = "${var.project_name}-primary-pub-rt" }
}

resource "aws_route_table_association" "primary_public" {
  provider       = aws.primary
  count          = 2
  subnet_id      = aws_subnet.primary_public[count.index].id
  route_table_id = aws_route_table.primary_public.id
}

resource "aws_route_table" "primary_private" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.primary.id
  }
  tags = { Name = "${var.project_name}-primary-priv-rt" }
}

resource "aws_route_table_association" "primary_private" {
  provider       = aws.primary
  count          = 2
  subnet_id      = aws_subnet.primary_private[count.index].id
  route_table_id = aws_route_table.primary_private.id
}

# --- SECONDARY VPC (ap-southeast-1) ---
resource "aws_vpc" "secondary" {
  provider             = aws.secondary
  cidr_block           = var.secondary_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-secondary-vpc" }
}

resource "aws_internet_gateway" "secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id
  tags     = { Name = "${var.project_name}-secondary-igw" }
}

resource "aws_subnet" "secondary_public" {
  provider                = aws.secondary
  count                   = 2
  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = cidrsubnet(var.secondary_vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.secondary.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-secondary-pub-${count.index + 1}" }
}

resource "aws_subnet" "secondary_private" {
  provider          = aws.secondary
  count             = 2
  vpc_id            = aws_vpc.secondary.id
  cidr_block        = cidrsubnet(var.secondary_vpc_cidr, 8, count.index + 11)
  availability_zone = data.aws_availability_zones.secondary.names[count.index]
  tags              = { Name = "${var.project_name}-secondary-priv-${count.index + 1}" }
}

resource "aws_eip" "secondary_nat" {
  provider = aws.secondary
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-secondary-nat-eip" }
}

resource "aws_nat_gateway" "secondary" {
  provider      = aws.secondary
  allocation_id = aws_eip.secondary_nat.id
  subnet_id     = aws_subnet.secondary_public[0].id
  tags          = { Name = "${var.project_name}-secondary-nat" }
  depends_on    = [aws_internet_gateway.secondary]
}

resource "aws_route_table" "secondary_public" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary.id
  }
  tags = { Name = "${var.project_name}-secondary-pub-rt" }
}

resource "aws_route_table_association" "secondary_public" {
  provider       = aws.secondary
  count          = 2
  subnet_id      = aws_subnet.secondary_public[count.index].id
  route_table_id = aws_route_table.secondary_public.id
}

resource "aws_route_table" "secondary_private" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.secondary.id
  }
  tags = { Name = "${var.project_name}-secondary-priv-rt" }
}

resource "aws_route_table_association" "secondary_private" {
  provider       = aws.secondary
  count          = 2
  subnet_id      = aws_subnet.secondary_private[count.index].id
  route_table_id = aws_route_table.secondary_private.id
}