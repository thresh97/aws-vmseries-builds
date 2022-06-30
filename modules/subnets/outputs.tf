# output subnet_id {
#   value = values(aws_subnet.main)[*].id
# }


# output "subnet_id" {
    
#     value = {
#         for i in aws_subnet.main:
#         aws_subnet.main[each.key].id //toset(values(aws_subnet.main)[*].id)
#     }
# }



# output subnet_id {

#     value = values(aws_subnet.main)[*]["id"]
# }






# output subnet_id {
#     value = aws_subnet.main.${each.key}.id
# }

# output "subnet_id" {
    
#     value = {
#         for i in aws_subnet.main:
#         aws_subnet.main[each.key].id //toset(values(aws_subnet.main)[*].id)
#     }
# }

# output subnet_id {
#   value = {
#     for i in aws_subnet.main:
#     subnet_id.id
#   }
# }
