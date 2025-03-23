data "oci_identity_availability_domain" "ad" {
  compartment_id = var.compartment_ocid
  ad_number      = var.availability_domain
}
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}