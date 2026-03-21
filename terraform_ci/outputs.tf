output "jenkins_url" {
  value = "http://${module.jenkins.public_ip}:8080"
}