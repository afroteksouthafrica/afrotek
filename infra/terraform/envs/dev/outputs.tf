// Dev outputs

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "auth_service_name" {
  value = aws_ecs_service.auth.name
}
