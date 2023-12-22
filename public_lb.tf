resource "aws_lb_target_group" "master_public_tg" {
  name = "${var.application}-master-public-tg"

  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.vpc.id
  deregistration_delay = 30

  health_check {
    port                = "traffic-port"
    path                = "/login"
    timeout             = 25
    healthy_threshold   = 2
    unhealthy_threshold = 4
    matcher             = "200-299"
  }

  tags = merge(
    var.tags,
    tomap({
      "Name" = "${var.application}-master-public-tg"
    })
  )
}

resource "aws_lb_listener" "master_lb_public_listener" {
  load_balancer_arn = aws_lb.lb_public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = data.aws_acm_certificate.certificate.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = ""
      status_code  = "404"
    }

  }
}

resource "aws_lb_listener_rule" "github_webhook_public" {
  listener_arn = aws_lb_listener.master_lb_public_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.master_public_tg.arn
  }

  condition {
    path_pattern {
      values = ["/github-webhook/*"]
    }
  }

  condition {
    host_header {
      values = [aws_route53_record.r53_record_public.fqdn]
    }
  }
}

resource "aws_lb" "lb_public" {
  idle_timeout               = 60
  internal                   = false
  name                       = "${var.application}-public-lb"
  security_groups            = [
    aws_security_group.lb_sg_public.id]
  subnets                    = [
    data.aws_subnet.public_subnet_az1.id, data.aws_subnet.public_subnet_az2.id]
  enable_deletion_protection = false

  tags = merge(
    var.tags,
    tomap({
      "Name" = "${var.application}-public-lb"
    })
  )
}

resource "aws_route53_record" "r53_record_public" {
  zone_id = data.aws_route53_zone.r53_zone.zone_id
  name    = "webhook-${var.r53_record}"
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.lb_public.dns_name}"
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_security_group" "lb_sg_public" {
  name        = "${var.application}-lb-public-sg"
  description = "${var.application}-lb-public-sg"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_ingress
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_cidr_ingress
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    tomap({
      "Name" = "${var.application}-lb-sg-public"
    })
  )
}