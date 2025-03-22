variable "arch" {
  description = "The Talos architecture list"
  type        = list(string)
  default     = ["amd64", "arm64"]
}
variable "talos_version" {
  default = "v1.9.0"
}
variable "kernel_args" {
 default = []
}
variable "extensions" {
  default = []
}