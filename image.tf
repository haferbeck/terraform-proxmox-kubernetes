locals {
  talos_schematic_id = var.talos_schematic_id != null ? var.talos_schematic_id : talos_image_factory_schematic.this[0].id

  talos_installer_image_url = data.talos_image_factory_urls.this.urls.installer
  talos_iso_image_url       = data.talos_image_factory_urls.this.urls.iso

  talos_image_extensions_longhorn = [
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools"
  ]

  talos_image_extensions_piraeus = [
    "siderolabs/drbd",
    "siderolabs/util-linux-tools"
  ]

  talos_image_extensions = distinct(
    concat(
      ["siderolabs/qemu-guest-agent"],
      var.talos_image_extensions,
      var.longhorn_enabled ? local.talos_image_extensions_longhorn : [],
      var.piraeus_enabled ? local.talos_image_extensions_piraeus : []
    )
  )

  talos_image_filename = "talos-${var.talos_version}-${substr(local.talos_schematic_id, 0, 8)}.iso"
}

data "talos_image_factory_extensions_versions" "this" {
  count = var.talos_schematic_id == null ? 1 : 0

  talos_version = var.talos_version
  filters = {
    names = local.talos_image_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  count = var.talos_schematic_id == null ? 1 : 0

  schematic = yamlencode(
    {
      customization = {
        extraKernelArgs = var.talos_extra_kernel_args
        systemExtensions = {
          officialExtensions = (
            length(local.talos_image_extensions) > 0 ?
            data.talos_image_factory_extensions_versions.this[0].extensions_info.*.name :
            []
          )
        }
      }
    }
  )
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = local.talos_schematic_id
  platform      = "nocloud"
  architecture  = "amd64"
}

# Proxmox downloads the ISO directly from Talos Image Factory
resource "proxmox_download_file" "talos_image" {
  content_type = "iso"
  datastore_id = var.proxmox_image_storage
  node_name    = var.proxmox_node
  url          = local.talos_iso_image_url
  file_name    = local.talos_image_filename

  checksum           = var.talos_iso_checksum
  checksum_algorithm = var.talos_iso_checksum != null ? "sha256" : null
}
