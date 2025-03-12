output "control_plane_ip" {
  value = [oci_core_instance.talos_controlplane.public_ip]
}