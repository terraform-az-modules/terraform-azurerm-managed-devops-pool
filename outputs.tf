##-----------------------------------------------------------------------------
## Managed DevOps Pool Outputs
##-----------------------------------------------------------------------------
output "managed_devops_pool_id" {
  value       = try(azurerm_managed_devops_pool.default[0].id, null)
  description = "The ID of the Managed DevOps Pool."
}

output "managed_devops_pool_name" {
  value       = var.enable ? local.managed_devops_pool_name : null
  description = "The name of the Managed DevOps Pool and Azure DevOps agent pool."
}

##-----------------------------------------------------------------------------
## Dev Center Outputs
##-----------------------------------------------------------------------------
output "dev_center_id" {
  value       = var.enable ? local.dev_center_id : null
  description = "The created or supplied Dev Center ID."
}

output "dev_center_name" {
  value       = var.enable && var.create_dev_center ? local.dev_center_name : null
  description = "The name of the Dev Center created by the module."
}

##-----------------------------------------------------------------------------
## Dev Center Project Outputs
##-----------------------------------------------------------------------------
output "dev_center_project_id" {
  value       = var.enable ? local.dev_center_project_id : null
  description = "The created or supplied Dev Center Project ID."
}

output "dev_center_project_name" {
  value       = var.enable && var.create_dev_center_project ? local.dev_center_project_name : null
  description = "The name of the Dev Center Project created by the module."
}

##-----------------------------------------------------------------------------
## Configuration Outputs
##-----------------------------------------------------------------------------
output "azure_devops_organization_urls" {
  value       = [for organization in var.azure_devops_organizations : organization.url]
  description = "Azure DevOps organization URLs associated with the pool."
}

output "subnet_id" {
  value       = var.subnet_id
  description = "The delegated subnet ID used by the pool agents."
}

output "tags" {
  value       = module.labels.tags
  description = "Tags applied to resources created by this module."
}