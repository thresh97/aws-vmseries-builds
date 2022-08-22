resource "aws_lb" "gwlb" {
  name               = "${random_id.deployment_id.hex}-gwlb"
  internal           = false
  load_balancer_type = "gateway"
  subnets            = [module.vmseries_subnets.subnet_ids["gwlbe-az1"], module.vmseries_subnets.subnet_ids["gwlbe-az2"], module.vmseries_subnets.subnet_ids["gwlbe-az3"]]
  enable_cross_zone_load_balancing = true 
}

resource "aws_lb_target_group" "gwlb" {
  name        = "${random_id.deployment_id.hex}-gwlb-tg"
  port        = 6081
  protocol    = "GENEVE"
  target_type = "instance"
  vpc_id      = aws_vpc.security.id
  deregistration_delay = 5

  health_check {
    port = 80
    protocol = "TCP"
    interval = 5
    unhealthy_threshold = 3
  }
}
resource "aws_vpc_endpoint_service" "gwlb" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = {
    Name = "${random_id.deployment_id.hex}_endpoint-service"
  }

}
resource "aws_vpc_endpoint" "az1" {
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  subnet_ids        = [module.vmseries_subnets.subnet_ids["gwlbe-az1"]]
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlb.service_type
  vpc_id            = aws_vpc.security.id

  tags = {
    Name = "${random_id.deployment_id.hex}_endpoint-az1"
  }
}

resource "aws_vpc_endpoint" "az2" {
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  subnet_ids        = [module.vmseries_subnets.subnet_ids["gwlbe-az2"]]
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlb.service_type
  vpc_id            = aws_vpc.security.id

  tags = {
    Name = "${random_id.deployment_id.hex}_endpoint-az2"
  }
}

resource "aws_vpc_endpoint" "az3" {
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  subnet_ids        = [module.vmseries_subnets.subnet_ids["gwlbe-az3"]]
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlb.service_type
  vpc_id            = aws_vpc.security.id

  tags = {
    Name = "${random_id.deployment_id.hex}_endpoint-az3"
  }
}

resource "aws_lb_listener" "gwlb" {
  load_balancer_arn = aws_lb.gwlb.id

  default_action {
    target_group_arn = aws_lb_target_group.gwlb.id
    type             = "forward"
  }
}
