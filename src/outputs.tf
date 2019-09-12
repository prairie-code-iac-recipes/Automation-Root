output "ssh_private_key" {
  value       = "${base64encode(tls_private_key.ssh_key_pair.private_key_pem)}"
  sensitive   = true
}
output "ssh_public_key" {
  value = "${base64encode(tls_private_key.ssh_key_pair.public_key_openssh)}"
}
