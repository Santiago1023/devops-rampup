
# output "domain-name" {
#   value = aws_instance.web.public_dns
# }

# output "application-url" {
# #   value = "${aws_instance.web.public_dns}/index.php"
#   value = "${aws_instance.web.public_dns}"
# }

output "elb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.elb.dns_name
}