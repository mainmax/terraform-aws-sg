resource  "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id
}

locals {
  map = merge( 
    {
      "IN"              = "ingress"
      "OUT"             = "egress"
      "ALL TRAFFIC"     = "ALL ALL"                                
      "Any_IPv4"        = "0.0.0.0/0"
      "Any_IPv6"        = "::/0"
      "SSH"             = "TCP 22"
      "SMTP"            = "TCP 25"
      "DNS_UDP"         = "UDP 53"
      "DNS_TCP"         = "TCP 53"
      "HTTP"            = "TCP 80"
      "POP3"            = "TCP 110"
      "IMAP"            = "TCP 143"
      "LDAP"            = "TCP 386"
      "HTTPS"           = "TCP 443"
      "SMB"             = "TCP 445"
      "SMTPS"           = "TCP 465"
      "IMAPS"           = "TCP 993"
      "POP3S"           = "TCP 995"
      "MSSQL"           = "TCP 1433"
      "NFS"             = "TCP 2049"
      "MYSQL"           = "TCP 3306"
      "RDP"             = "TCP 3389"
      "Redshift"        = "TCP 5439"
      "PostgreSQL"      = "TCP 5432"
      "Oracle-RDS"      = "TCP 1521"
      "WinRM-HTTP"      = "TCP 5985"
      "WinRM-HTTPS"     = "TCP 5986"
      "Elastic Graphics"= "TCP 5432"
      "PING"            = "ICMP 8-0"
    }, 
    {for k,v in var.rules_vars: "{${k}}" => v}
  )

  r  = replace(replace(var.rules,
        "/(?m)^[ \\t]+|[ \\t]+$/",""),            # trim whitespaces
        "/[ \\t]+/"," ")                          # convert multiple whitespaces into a single one
  
  rr = {for idx, line in split("\n",local.r):     # extract array of "rules"
        idx => can(split(" - ", line)[0]) ? split(" - ", line)[0] : line
        if (line != "" && substr(line,0,1) != "#")
      }

  rd = {for idx, line in split("\n",local.r):     # extract array of "descriptions"
        idx => can(split(" - ", line)[1]) ? split(" - ", line)[1] : ""
        if (line != "" && substr(line,0,1) != "#")
      }

  rk = {for idx, l in local.rr:                                 # create resource keys map
        join("_",split(" ",replace(l,"/{(.*)}/","$1"))) => idx  # with values referencing rule "line number"
        }                                                       # remove templating symbls {...} for cleaner resource keys
  
  rv = {for idx, line in local.rr:                                      # create rules values map
        idx => split(" ", format(                                       # with keys referencing rule "line number"
          replace(line, "/(${join("|", keys(local.map))})/", "%s"),     # some dictionary replacement magic   
          [                                                             # thanks to https://stackoverflow.com/users/1239484/allejo
            for value in flatten(regexall("(${join("|", keys(local.map))})", line)) :
              lookup(local.map, value)
          ]...
        ))}
}

resource "aws_security_group_rule" "this" {
  for_each = local.rk

  type        = local.rv[each.value][0]
  from_port   = local.rv[each.value][2] == "ALL" ? -1 : can(regex("-",local.rv[each.value][2])) ? split("-",local.rv[each.value][2])[0] : local.rv[each.value][2]
  to_port     = local.rv[each.value][2] == "ALL" ? -1 : can(regex("-",local.rv[each.value][2])) ? split("-",local.rv[each.value][2])[1] : local.rv[each.value][2]
  protocol    = local.rv[each.value][1]
  cidr_blocks       = can(regex("[.]",local.rv[each.value][3])) ? [for c in split(",",local.rv[each.value][3]): c if can(regex("[.]", c))] : null
  ipv6_cidr_blocks  = can(regex("[:]",local.rv[each.value][3])) ? [for c in split(",",local.rv[each.value][3]): c if can(regex("[:]", c))] : null
  source_security_group_id = can(regex("^sg-", local.rv[each.value][3])) ? local.rv[each.value][3] : null
  prefix_list_ids          = can(regex("^pl-", local.rv[each.value][3])) ? split(",", local.rv[each.value][3]) : null
  self                     = local.rv[each.value][3] == "self" ? true : null
  description = local.rd[each.value]
  security_group_id = aws_security_group.this.id
}