##-----------------------------------------------------------------------------
## VNet Permissions for the DevOpsInfrastructure Service Principal
##-----------------------------------------------------------------------------
resource "azurerm_role_assignment" "devops_infrastructure_reader" {
  count = var.enable && var.create_network_role_assignments ? 1 : 0

  scope                            = var.virtual_network_id
  role_definition_name             = "Reader"
  principal_id                     = var.devops_infrastructure_principal_id
  skip_service_principal_aad_check = true

  # depends_on = [terraform_data.validation]
}

resource "azurerm_role_assignment" "devops_infrastructure_network_contributor" {
  count = var.enable && var.create_network_role_assignments ? 1 : 0

  scope                            = var.virtual_network_id
  role_definition_name             = "Network Contributor"
  principal_id                     = var.devops_infrastructure_principal_id
  skip_service_principal_aad_check = true

  # depends_on = [terraform_data.validation]
}
