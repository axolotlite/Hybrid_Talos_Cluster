locals {
    build_path = "${path.module}/build/${var.talos_version}"
}
resource "talos_image_factory_schematic" "this" {
  # leaving this here for when I need to install extensions
  schematic = yamlencode(
    {
      customization = {
        extraKernelArgs = var.kernel_args
        systemExtensions = {
            officialExtensions = var.extensions
        }
      }
    }
  )
}
data "talos_image_factory_urls" "arch" {
  for_each = toset(var.arch)
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  architecture = each.value
  platform      = "oracle"
}

resource "local_file" "metadata" {
  for_each = toset(var.arch)
  content  = templatefile("${path.module}/template/image_metadata_${each.value}.json",{version = var.talos_version})
  filename = "${local.build_path}/${each.value}/image_metadata.json"
}

resource "null_resource" "download_images" {
  for_each = toset(var.arch)

  depends_on = [ local_file.metadata ]
  triggers = {
    on_version_change = "${data.talos_image_factory_urls.arch[each.key].urls.disk_image}"
  }
  provisioner local-exec { 
    interpreter = ["/bin/bash" ,"-c"]
    working_dir = "${local.build_path}/${each.key}"
    command = <<-EOT
      curl -C - -o oracle-${each.key}.raw.xz ${data.talos_image_factory_urls.arch[each.key].urls.disk_image}
      xz -fdk oracle-${each.key}.raw.xz
      qemu-img convert -f raw -O qcow2 oracle-${each.key}.raw oracle-${each.key}.qcow2
      rm oracle-${each.key}.raw
      tar zcf oracle-${each.key}.oci oracle-${each.key}.qcow2 image_metadata.json
    EOT
  }
}