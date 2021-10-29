variable "bastion_ip" {
  default = "192.168.1.100"
}

resource "aws_vpc" "test" {
  cidr_block  = "10.0.0.0/16"

  tags = {
    "Name"    = "TF Test VPC"
  }
}

# Simple rule using TERMs replacement from buld-in vocabulary
# SSH -> TCP 22, Any_IPv4 -> 0.0.0.0/0

module "sg_bastion" {
  source      = "../../"
  name        = "TF Test Bastion"
  description = "Test SG for Bastion"
  vpc_id      = aws_vpc.test.id
  rules = "ingress SSH Any_IPv4 - SSH for Bastion"
}

# Rules can be formatted with spaces and TABs
# Dynamic values that are available during Apply can be added with combination of
# {var} template and additional module parameter "rules_vars", where "var" = value 

module "sg_web" {
  source      = "../../"
  name        = "TF Test Web"
  description = "Test SG for Web services"
  vpc_id      = aws_vpc.test.id
  rules = <<EOF
    IN  TCP  80   Any_IPv4,Any_IPv6 - HTTP Inbound
    IN  TCP  443  0.0.0.0/0,::/0    - HTTPS Inbound
    IN  TCP  8005 {bastion_ip}/32   - Tomcat admin from Bastion
    IN  PING      0.0.0.0/0,::/0    - PING from Internet
    OUT TCP  3306 {sg_db}           - Outbound to MySql DB
    OUT TCP  443  pl-02cd2c6b       - DynamoDB Prefix List
  EOF
  rules_vars = {
    "sg_db"      = module.sg_db.id
    "bastion_ip" = var.bastion_ip
  }
}

# lines can be commented with "#" in the beginning
# rule description can be ommited 
# port ranges are supported with dash and no spaces "from_port-to_port" 
module "sg_db" {
  source      = "../../"
  name        = "TF Test DB"
  description = "Test SG for DB services"
  vpc_id      = aws_vpc.test.id
  rules = <<EOF
  # Inbound Rules
    IN TCP 3306 {sg_web} - MySql Inbound from WEB
    IN ALL TRAFFIC self - Master-Slave replicaton
    IN ICMP ALL {bastion_ip}/32 - ICMP from Bastion
  # Outbound Rules
    OUT ALL TRAFFIC self
    OUT UDP 514-517 10.0.0.5/32,10.0.1.5/32 - SYSLOG Servers
  EOF
  rules_vars = {
    "sg_web"     = module.sg_web.id
    "bastion_ip" = var.bastion_ip
  }
}

