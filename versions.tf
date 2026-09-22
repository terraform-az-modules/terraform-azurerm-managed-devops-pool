##-----------------------------------------------------------------------------
## Versions
##-----------------------------------------------------------------------------
# Terraform version
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Verified directly against azurerm 5.6.0: azurerm_managed_devops_pool,
      # azurerm_dev_center, and azurerm_dev_center_project (with
      # virtual_machine_scale_set_fabric, stateless_agent/stateful_agent,
      # and azure_devops_organization blocks) all validate cleanly on 5.x —
      # this module's resource schema has no 4.x-only dependency. The
      # dependabot-driven ceiling bumps below track azurerm releases, not a
      # known incompatibility; no upper bound is required functionally.
      version = ">= 4.68.0, < 5.7"
    }
  }
}