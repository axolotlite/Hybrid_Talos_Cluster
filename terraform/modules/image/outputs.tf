output "images" {
  value = {for arch,file in local_file.images : arch =>file.filename}
}