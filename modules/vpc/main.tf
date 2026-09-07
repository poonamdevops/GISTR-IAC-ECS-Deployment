# ---------------------------------------------------------------------------
# Module: vpc  (3-tier network)
# ---------------------------------------------------------------------------
# Creates a VPC with three subnet tiers in the primary AZ:
#   - public       : ALB + NAT Gateway (routes to Internet Gateway)
#   - private_app  : EC2 app servers   (outbound via NAT Gateway)
#   - private_data : reserved/isolated (no internet route) - future DB/cache
#
# A small SECOND public subnet is created in a second AZ ONLY to satisfy the
# ALB requirement of 2 subnets in 2 AZs. Everything else stays single-AZ to
# keep Dev cost-optimized. For Prod, set multi_az = true to fully populate AZ2.
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_primary   = data.aws_availability_zones.available.names[0]
  az_secondary = data.aws_availability_zones.available.names[1]
}

# ---- VPC ------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

# ---- Internet Gateway (for public subnets) --------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# ---- Subnets --------------------------------------------------------------
# Public subnet (primary AZ) - holds ALB + NAT.
resource "aws_subnet" "public_primary" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.az_primary
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-1"
    Tier = "public"
  })
}

# Public subnet (secondary AZ) - exists so the ALB has 2 AZs. No NAT here.
resource "aws_subnet" "public_secondary" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_secondary_cidr
  availability_zone       = local.az_secondary
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-2"
    Tier = "public"
  })
}

# Private app subnet (primary AZ) - EC2 workloads.
resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidr
  availability_zone = local.az_primary
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-app-1"
    Tier = "private-app"
  })
}

# Private data subnet (primary AZ) - isolated, no internet. Future DB/cache.
resource "aws_subnet" "private_data" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_data_subnet_cidr
  availability_zone = local.az_primary
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-data-1"
    Tier = "private-data"
  })
}

# ---- NAT Gateway (single, in the primary public subnet) -------------------
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_primary.id
  tags          = merge(var.tags, { Name = "${var.name_prefix}-nat" })

  depends_on = [aws_internet_gateway.this]
}

# ---- Route tables ---------------------------------------------------------
# Public route table: default route to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route_table_association" "public_primary" {
  subnet_id      = aws_subnet.public_primary.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_secondary" {
  subnet_id      = aws_subnet.public_secondary.id
  route_table_id = aws_route_table.public.id
}

# Private app route table: default route to the NAT Gateway (outbound only).
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-rt-private-app" })
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private_app.id
}

# Private data route table: NO internet route (isolated). Local traffic only.
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-private-data" })
}

resource "aws_route_table_association" "private_data" {
  subnet_id      = aws_subnet.private_data.id
  route_table_id = aws_route_table.private_data.id
}
