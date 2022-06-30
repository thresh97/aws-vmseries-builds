variable "subnets" {
  type        = map(map(any))
  default     = {}
}

variable cidr_block {
  default = "10.0.0.0/16"
}


resource "aws_subnet" "main" {
  for_each = var.subnets

  vpc_id            = var.vpc_id
  availability_zone = each.value["az"]
  cidr_block        = each.value["cidr"]

    tags = merge(
    {
      Name =  format("%s", "${var.subnet_name_prefix}${each.key}") // format("%s", each.key)
      IpType = "subnet"
    }
  )
}


# resource "aws_route_table_association" "main" {
#   for_each = var.subnets
#   subnet_id = aws_subnet.main[each.key].id
#   route_table_id = each.value.route_table_id
# }

output "subnet_ids" {

   value = tomap({
    for k, b in aws_subnet.main : k => b.id
  })
}

output "azs" {

   value = tomap({
    for k, b in aws_subnet.main : k => b.availability_zone
  })
}

# locals {
#   subnets = {
#     for i in var.subnets :
#     i.index => i
#   }
# }

# resource "aws_subnet" "main" {
#   for_each = local.subnets
#   vpc_id   = var.vpc_id 
#   cidr_block = each.value.cidr_block
#   availability_zone = each.value.availability_zone
#   tags = merge(
#     {
#       "Name" = format("%s", each.value.name)
#     }
#   )

# }

# # resource "aws_route_table_association" "main" {
# #   for_each = local.subnets
# #   subnet_id = aws_subnet.main[each.key].id
# #   route_table_id = each.value.route_table_id

# #  // depends_on = [aws_subnet.main]
# # }


# output subnet_id {
#    value = values(aws_subnet.main)[*].id
# }












# locals {
#   subnets = {
#     for i in var.subnets :
#     i.name => i
#   }
# }

# resource "aws_subnet" "main" {
#   for_each = local.subnets
#   vpc_id   = var.vpc_id
#   cidr_block = each.value.cidr_block
#   availability_zone = each.value.availability_zone
#   tags = {
#     Name = each.value.name
#   }

# }



# output subnet_id {
#  //  value = [for v in aws_subnet.main : v.id]
#  // value = toset([for v in aws_subnet.main : v.id])
#   //value = tolist(var.subnets)[0]
# //value = tolist(values(aws_subnet.main)[*].id)
# //   value = values(aws_subnet.main)[*].id
# }
