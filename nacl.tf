resource "aws_network_acl" "db_secure_zone" {
  vpc_id     = aws_vpc.project_vpc.id
  subnet_ids = aws_subnet.private_db_subnets[*].id
}
resource "aws_network_acl" "app_secure_zone" {
  vpc_id     = aws_vpc.project_vpc.id
  subnet_ids = aws_subnet.private_app_subnets[*].id
}
resource "aws_network_acl" "alb_zone" {
  vpc_id     = aws_vpc.project_vpc.id
  subnet_ids = aws_subnet.public_subnets[*].id
}


locals {
  alb_nacl_ingress_rules = flatten([
    {
      cidr_block = "0.0.0.0/0"
      priority   = 101
      from_port  = 0
      to_port    = 65535
      protocol   = "tcp"
      direction  = "ingress"
    }
  ])
  alb_nacl_egress_rules = flatten([
    # Egress Rules
    {
      cidr_block = "0.0.0.0/0"
      priority   = 102
      from_port  = 0
      to_port    = 65535
      protocol   = "tcp"
      direction  = "egress"
    }
  ])
  app_nacl_ingress_rules = flatten([
    # Ingress Rules for DB Subnets
    {
      cidr_block = var.private_db_subnets_cidr[0] # Allow traffic on ephermal ports from Private DB-1
      priority   = 101
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "ingress"
    },
    {
      cidr_block = var.private_db_subnets_cidr[1] # Allow traffic on ephermal ports from Private DB-2
      priority   = 102
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "ingress"
    },
    # Ingress Rules for ALB Public Subnets. We use Only http for simplicity in this project.
    {
      cidr_block = var.public_subnets_cidr[0]
      priority   = 103
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      direction  = "ingress"
    },
    {
      cidr_block = var.public_subnets_cidr[1]
      priority   = 104
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      direction  = "ingress"
    },
    {
      cidr_block = "0.0.0.0/0"
      priority   = 105
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "ingress"
    }
  ])
  app_nacl_egress_rules = flatten([
    # Egress Rules
    {
      cidr_block = var.public_subnets_cidr[0] # Allow outgoing traffic on ephermal ports to Public Subnet
      priority   = 201
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = var.public_subnets_cidr[1] # Allow outgoing traffic on ephermal ports to Public Subnet
      priority   = 202
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = var.private_db_subnets_cidr[0] # Allow outgoing traffic on db port to Private DB-1
      priority   = 203
      from_port  = 3306
      to_port    = 3306
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = var.private_db_subnets_cidr[1] # Allow outgoing traffic on db port to Private DB-2
      priority   = 204
      from_port  = 3306
      to_port    = 3306
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = "0.0.0.0/0"
      priority   = 205
      from_port  = 80
      to_port    = 80
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = "0.0.0.0/0"
      priority   = 206
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = "0.0.0.0/0"
      priority   = 207
      from_port  = 53
      to_port    = 53
      protocol   = "tcp"
      direction  = "egress"
    }
  ])
  db_nacl_ingress_rules = flatten([
    # Ingress Rules for DB Subnets
    {
      cidr_block = var.private_db_subnets_cidr[0] # Private DB-1
      priority   = 101
      from_port  = 3306
      to_port    = 65535
      protocol   = "tcp"
      direction  = "ingress"
    },
    {
      cidr_block = var.private_db_subnets_cidr[1] # Private DB-2
      priority   = 102
      from_port  = 3306
      to_port    = 65535
      protocol   = "tcp"
      direction  = "ingress"
    },
    # Ingress Rules for App Subnets
    {
      cidr_block = var.private_app_subnets_cidr[0] # Private App-1
      priority   = 103
      from_port  = 3306
      to_port    = 3306
      protocol   = "tcp"
      direction  = "ingress"
    },
    {
      cidr_block = var.private_app_subnets_cidr[1] # Private App-2
      priority   = 104
      from_port  = 3306
      to_port    = 3306
      protocol   = "tcp"
      direction  = "ingress"
    }
  ])

  db_nacl_egress_rules = flatten([
    # Egress Rules
    {
      cidr_block = var.private_app_subnets_cidr[0] # Allow outgoing traffic on ephermal ports to Private App-1
      priority   = 201
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = var.private_app_subnets_cidr[1] # Allow outgoing traffic on ephermal ports to Private App-2
      priority   = 202
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = var.private_db_subnets_cidr[0] # Allow outgoing traffic on ephermal ports to Private DB-1
      priority   = 203
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "egress"
    },
    {
      cidr_block = var.private_db_subnets_cidr[1] # Allow outgoing traffic on ephermal ports to Private DB-2
      priority   = 204
      from_port  = 1024
      to_port    = 65535
      protocol   = "tcp"
      direction  = "egress"
    }
  ])
}

# Ingress Rules for DB NACL (applies to DB subnets)
resource "aws_network_acl_rule" "db-ingress-secure-zone-rules" {
  for_each = { for rule in local.db_nacl_ingress_rules : rule.priority => rule }

  network_acl_id = aws_network_acl.db_secure_zone.id
  rule_number    = each.value.priority
  egress         = false
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# Egress Rules for DB NACL (applies to DB subnets)
resource "aws_network_acl_rule" "db-egress-secure-zone-rules" {
  for_each = { for rule in local.db_nacl_egress_rules : rule.priority => rule }

  network_acl_id = aws_network_acl.db_secure_zone.id
  rule_number    = each.value.priority
  egress         = true
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# Ingress Rules for APP NACL (applies to APP subnets)
resource "aws_network_acl_rule" "app-ingress-secure-zone-rules" {
  for_each = { for rule in local.app_nacl_ingress_rules : rule.priority => rule }

  network_acl_id = aws_network_acl.app_secure_zone.id
  rule_number    = each.value.priority
  egress         = false
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# Egress Rules for APP NACL (applies to APP subnets)
resource "aws_network_acl_rule" "app-egress-secure-zone-rules" {
  for_each = { for rule in local.app_nacl_egress_rules : rule.priority => rule }

  network_acl_id = aws_network_acl.app_secure_zone.id
  rule_number    = each.value.priority
  egress         = true
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# Ingress Rules for ALB NACL 
resource "aws_network_acl_rule" "alb-ingress-secure-zone-rules" {
  for_each = { for rule in local.alb_nacl_ingress_rules : rule.priority => rule }

  network_acl_id = aws_network_acl.alb_zone.id
  rule_number    = each.value.priority
  egress         = false
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

# Egress Rules for ALB NACL 
resource "aws_network_acl_rule" "alb-egress-secure-zone-rules" {
  for_each = { for rule in local.alb_nacl_egress_rules : rule.priority => rule }

  network_acl_id = aws_network_acl.alb_zone.id
  rule_number    = each.value.priority
  egress         = true
  protocol       = each.value.protocol
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}
