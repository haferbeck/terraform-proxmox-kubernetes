variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint, e.g. https://pve.example.com:8006"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox VE API token, format <user>!<token-id>=<token-value>."
}

variable "proxmox_insecure" {
  type        = bool
  default     = false
  description = "Skip TLS verification when talking to Proxmox. Only enable for self-signed lab certs."
}
