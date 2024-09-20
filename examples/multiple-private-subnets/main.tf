module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.0.0"

  ipv4_primary_cidr_block                   = "172.16.0.0/16"

  context = module.this.context
}

locals {
  # This is just an example showing how to avoid overlapping, you'll need to play with the `cidrsubnet` function to get the size you need.
  # If more control is required, it is advised to use `ipv4_cidrs` to directly set the CIDRs bypassing the module's logic.
  subnets    = cidrsubnet(module.vpc.vpc_cidr_block, 1, 0)
  subnets_db = cidrsubnet(module.vpc.vpc_cidr_block, 1, 1)
}

module "subnets" {
  source = "../../"

  availability_zones      = var.availability_zones
  vpc_id                  = module.vpc.vpc_id
  igw_id                  = [module.vpc.igw_id]
  ipv4_enabled            = true
  ipv4_cidr_block         = [local.subnets]
  nat_gateway_enabled     = true
  route_create_timeout    = "5m"
  route_delete_timeout    = "10m"

  context = module.this.context
}

# Additional 3 subnets for DBs

module "subnets_db" {
  source = "../../"

  availability_zones      = var.availability_zones
  vpc_id                  = module.vpc.vpc_id
  igw_id                  = [module.vpc.igw_id]
  ipv4_enabled            = true
  public_subnets_enabled  = false
  ipv4_cidr_block         = [local.subnets_db]
  nat_gateway_enabled     = false
  route_create_timeout    = "5m"
  route_delete_timeout    = "10m"

  context = module.this.context
}

resource "aws_route" "private_db" {
  count                  = length(module.subnets_db.private_route_table_ids)
  route_table_id         = module.subnets_db.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.subnets.nat_gateway_ids[count.index]
}
