# terraform-aws-sg
## Terraform module to create AWS EC2 Security Group from a firewall-like ruleset policy

This Terraform module deploys an EC2 Security Group into specified VPC with ingress/egress rules generated from a 'policy document' in plain text format.

From this:
```code
    IN  TCP  80   Any_IPv4,Any_IPv6 - HTTP Inbound
    IN  TCP  443  0.0.0.0/0,::/0    - HTTPS Inbound
    IN  TCP  8005 {bastion_ip}/32   - Tomcat admin from Bastion
    IN  PING      0.0.0.0/0,::/0    - PING from Internet
    OUT TCP  3306 {sg_db}           - Outbound to MySql DB
    OUT TCP  443  pl-02cd2c6b       - DynamoDB Prefix List
```
to this:
![](https://github.com/mainmax/terraform-aws-sg/raw/master/docs/img/aws-sg-rules.png)

Motivation for this module was to allow people that are not familiar with terraform (like Network and InfoSec guys) to be able to create/review Security Groups configurations without HCL in a way. It also allows to directly copy/paste more readable Security Group rules between change tickets, technical documentation (if you maintain one) and TF templates. 

## Usage in Terraform

Simple rule using TERMs replacement from built-in vocabulary (check main.tf for available values, fork this repo to add your own)

SSH -> TCP 22, Any_IPv4 -> 0.0.0.0/0

```hcl
module "sg_bastion" {
  source      = "mainmax/sg/aws"
  name        = "TF Test Bastion"
  description = "Test SG for Bastion"
  vpc_id      = aws_vpc.test.id
  rules = "ingress SSH Any_IPv4 - SSH for Bastion"
}
```

Rules can be formatted with spaces and TABs

Dynamic values that are available during Apply can be added with combination of
{var} template and additional module parameter "rules_vars", where "var" = value 

```hcl
module "sg_web" {
  source      = "mainmax/sg/aws"
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
```

Lines can be commented with "#" in the beginning

Rule description can be ommited 

Port ranges are supported with dash and no spaces "from_port-to_port"

```hcl
module "sg_db" {
  source      = "mainmax/sg/aws"
  name        = "TF Test DB"
  description = "Test SG for DB services"
  vpc_id      = aws_vpc.test.id
  rules = <<EOF
  # Inbound Rules
    IN TCP 3306 {sg_web} - MySql Inbound from WEB
    IN ALL TRAFFIC self - Master-Slave replication
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
```

There is some extra logic goes into creating Terraform State in such a way, that adding/deleting/changing a particular rule will not require "replacement" of other rules or the whole Security Group. It should help someone who is using Sentinel or OPA policies to validate deployment footprint when doing incremental changes to your infrastructure.

```bash
$ terraform state list
...
module.sg_db.aws_security_group.this
module.sg_db.aws_security_group_rule.this["IN_ALL_TRAFFIC_self"]
module.sg_db.aws_security_group_rule.this["IN_ICMP_ALL_bastion_ip/32"]
module.sg_db.aws_security_group_rule.this["IN_TCP_3306_sg_web"]
module.sg_db.aws_security_group_rule.this["OUT_ALL_TRAFFIC_self"]
module.sg_db.aws_security_group_rule.this["OUT_UDP_514-517_10.0.0.5/32,10.0.1.5/32"]
...
```

## Authors

Originally created by [mainmax](http://github.com/mainmax)

## License

[MIT](LICENSE)
