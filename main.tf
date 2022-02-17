resource  "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id
}

locals {
  # Limit KEY length to 64 chars
  terms = merge( 
    {
      "IN"              = "ingress"
      "OUT"             = "egress"
      "ALL"             = "-1"
      "ALL TRAFFIC"     = "-1 -1"                                
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

  termsks = flatten([                                     # extract TERMs and sort them longest->shortest
    for i in range(64,0): [                               # as regex will process them in order
      for k in keys(local.terms): k if (length(k) == i)
      ]
    ])

  termsregx = join("|", local.termsks)                    # prepare alteration regex for TERM replacement

  r  = {for idx, line in split("\n", var.rules): idx =>
        trimspace(replace(line, "/[ \\t]+/"," "))               # convert multiple whitespaces into a single one and trim
        if (line != "" && substr(trimspace(line),0,1) != "#")   # skip empty and commented lines
    }
  
  rr = {for idx, line in local.r:                               # extract array of "rules"
        idx => try(split(" - ", line)[0], line)
      }

  rd = {for idx, line in local.r:                               # extract array of "descriptions"
        idx => try(split(" - ", line)[1], "")
      }

  rk = {for idx, l in local.rr:                                 # create resource keys map
        join("_",split(" ",replace(l,"/{(.*)}/","$1"))) => idx  # with values referencing rule "line number"
        }                                                       # remove templating symbls {...} for cleaner resource keys
  
  rv = {for idx, line in local.rr:                                      # create rules values map
        idx => split(" ", format(                                       # with keys referencing rule "line number"
          replace(line, "/(${local.termsregx})/", "%s"),                # some dictionary replacement magic   
          [                                                             # thanks to https://stackoverflow.com/users/1239484/allejo
            for value in flatten(regexall("(${local.termsregx})", line)) :
              lookup(local.terms, value)
          ]...
        ))}

  rvm = {for idx, v in local.rv:
           idx => {
             type         = v[0]
             protocol     = v[1]
             from_port    = try(regex("(\\d+)-(\\d+)",v[2])[0], v[2])
             to_port      = try(regex("(\\d+)-(\\d+)",v[2])[1], v[2])
             cidr_blocks      = can(regex("[.]",v[3])) ? [for c in split(",",v[3]): c if can(regex("[.]", c))] : null
             ipv6_cidr_blocks = can(regex("[:]",v[3])) ? [for c in split(",",v[3]): c if can(regex("[:]", c))] : null
             source_security_group_id = try(regex("^(sg-.*)", v[3])[0], null)
             prefix_list_ids          = try(flatten(regexall("(pl-\\w*)", v[3])), null)
             self                     = try({"self": true}[v[3]], null)
             description  = local.rd[idx]
           }

  }
}

resource "aws_security_group_rule" "this" {
  for_each = local.rk
  security_group_id = aws_security_group.this.id

  type                     = local.rvm[each.value].type
  protocol                 = local.rvm[each.value].protocol
  from_port                = local.rvm[each.value].from_port
  to_port                  = local.rvm[each.value].to_port
  cidr_blocks              = local.rvm[each.value].cidr_blocks
  ipv6_cidr_blocks         = local.rvm[each.value].ipv6_cidr_blocks
  source_security_group_id = local.rvm[each.value].source_security_group_id
  prefix_list_ids          = local.rvm[each.value].prefix_list_ids
  self                     = local.rvm[each.value].self
  description              = local.rvm[each.value].description
}