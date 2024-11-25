variable "access_key" {
    default = ""
}

variable "secret_key" {
    default = ""
}

variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for instances"
  type        = string
  default     = "Rishi"
}