##-----------------------------------------------------------------------------
## Locals
##-----------------------------------------------------------------------------
locals {
  name = var.custom_name != null ? var.custom_name : module.labels.id

  dev_center_name = var.custom_dev_center_name != null ? var.custom_dev_center_name : (
    var.resource_position_prefix ? format("dc-%s", local.name) : format("%s-dc", local.name)
  )

  dev_center_project_name = var.custom_dev_center_project_name != null ? var.custom_dev_center_project_name : (
    var.resource_position_prefix ? format("dcp-%s", local.name) : format("%s-dcp", local.name)
  )

  managed_devops_pool_name = var.custom_managed_devops_pool_name != null ? var.custom_managed_devops_pool_name : (
    var.resource_position_prefix ? format("mdp-%s", local.name) : format("%s-mdp", local.name)
  )

  dev_center_id = var.create_dev_center ? try(azurerm_dev_center.default[0].id, null) : var.dev_center_id

  dev_center_project_id = var.create_dev_center_project ? try(
    azurerm_dev_center_project.default[0].id,
    null
  ) : var.dev_center_project_id
}
