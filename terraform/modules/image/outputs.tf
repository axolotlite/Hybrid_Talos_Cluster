output "images" {
  value = {for arch in var.arch : arch => "${path.module}/build/${var.talos_version}/${arch}/oracle-${arch}.oci" }
}