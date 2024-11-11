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
