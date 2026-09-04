##-----------------------------------------------------------------------------
## Naming Convention
##-----------------------------------------------------------------------------
variable "custom_name" {
  type        = string
  default     = null
  description = "Override the base name produced by the standard labels module."
}

variable "custom_dev_center_name" {
  type        = string
  default     = null
  description = "Override the generated Dev Center resource name."
}

variable "custom_dev_center_project_name" {
  type        = string
  default     = null
  description = "Override the generated Dev Center Project resource name."
}

variable "custom_managed_devops_pool_name" {
  type        = string
  default     = null
  description = "Override the generated Managed DevOps Pool resource name."
}

variable "resource_position_prefix" {
  type        = bool
  default     = true
  description = <<EOT
Controls the placement of the resource type keyword in generated resource names.

- If true, the keyword is prepended, for example: mdp-core-dev-centralus.
- If false, the keyword is appended, for example: core-dev-centralus-mdp.
EOT
}

##-----------------------------------------------------------------------------
## Labels
##-----------------------------------------------------------------------------
variable "name" {
  type        = string
  default     = ""
  description = "Name, for example app, platform or mxcore."
}

variable "environment" {
  type        = string
  default     = ""
  description = "Environment, for example prod, dev, staging or shared."
}

variable "managedby" {
  type        = string
  default     = "terraform-az-modules"
  description = "ManagedBy tag value."
}

variable "extra_tags" {
  type        = map(string)
  default     = null
  description = "Additional tags to merge with the standard tags."
}

variable "repository" {
  type        = string
  default     = "https://github.com/terraform-az-modules/terraform-azurerm-managed-devops-pool"
  description = "Terraform module repository URL used in resource tags."

  validation {
    condition     = can(regex("^https://", var.repository))
    error_message = "repository must be a valid HTTPS URL."
  }
}

variable "location" {
  type        = string
  description = "Azure region where the Dev Center, Project and Managed DevOps Pool are created."
}

variable "deployment_mode" {
  type        = string
  default     = "terraform"
  description = "Specifies how the infrastructure is deployed."
}

variable "label_order" {
  type        = list(any)
  default     = ["name", "environment", "location"]
  description = "Order of labels used to construct names and tags."
}

##-----------------------------------------------------------------------------
## Global Variables
##-----------------------------------------------------------------------------
variable "resource_group_name" {
  type        = string
  description = "Name of the standard resource group in which resources are created. Do not use an Azure-managed resource group protected by a deny assignment."
}

variable "enable" {
  type        = bool
  default     = true
  description = "Set to false to prevent the module from creating resources."
}

##-----------------------------------------------------------------------------
## Dev Center
##-----------------------------------------------------------------------------
variable "create_dev_center" {
  type        = bool
  default     = true
  description = "Create a Dev Center. Set to false to use dev_center_id."
}

variable "dev_center_id" {
  type        = string
  default     = null
  description = "Existing Dev Center ID. Required when creating a project without creating a Dev Center."
}

variable "project_catalog_item_sync_enabled" {
  type        = bool
  default     = false
  description = "Whether project catalogs associated with the Dev Center can synchronize catalog items."
}

variable "dev_center_identity" {
  type = object({
    type         = string
    identity_ids = optional(list(string), [])
  })
  default     = null
  description = "Optional managed identity configuration for the Dev Center."
}

##-----------------------------------------------------------------------------
## Dev Center Project
##-----------------------------------------------------------------------------
variable "create_dev_center_project" {
  type        = bool
  default     = true
  description = "Create a Dev Center Project. Set to false to use dev_center_project_id."
}

variable "dev_center_project_id" {
  type        = string
  default     = null
  description = "Existing Dev Center Project ID. Required when create_dev_center_project is false."
}

variable "dev_center_project_description" {
  type        = string
  default     = "Managed DevOps Pool project managed by Terraform."
  description = "Description assigned to the Dev Center Project."
}

variable "maximum_dev_boxes_per_user" {
  type        = number
  default     = null
  description = "Optional maximum number of Dev Boxes each user can create across the project."
}

variable "dev_center_project_identity" {
  type = object({
    type         = string
    identity_ids = optional(list(string), [])
  })
  default     = null
  description = "Optional managed identity configuration for the Dev Center Project."
}

##-----------------------------------------------------------------------------
## Azure DevOps Organization Configuration
##-----------------------------------------------------------------------------
variable "azure_devops_organizations" {
  type = list(object({
    url         = string
    parallelism = number
    projects    = optional(list(string))
  }))
  description = "Azure DevOps organizations to connect to the pool. The parallelism total must equal maximum_concurrency."

  validation {
    condition = alltrue([
      for organization in var.azure_devops_organizations :
      organization.parallelism >= 1 && organization.parallelism <= 10000
    ])
    error_message = "Each organization parallelism value must be between 1 and 10000."
  }
}

variable "azure_devops_permission" {
  type = object({
    kind = string
    administrator_account = optional(object({
      groups = optional(list(string), [])
      users  = optional(list(string), [])
    }))
  })
  default     = null
  description = "Optional pool administrator permission configuration. kind supports Inherit or SpecificAccounts."

  validation {
    condition = var.azure_devops_permission == null ? true : contains(
      ["Inherit", "SpecificAccounts"],
      var.azure_devops_permission.kind
    )
    error_message = "azure_devops_permission.kind must be Inherit or SpecificAccounts."
  }
}

##-----------------------------------------------------------------------------
## Agent Profile and Scaling
##-----------------------------------------------------------------------------
variable "maximum_concurrency" {
  type        = number
  default     = 1
  description = "Maximum number of agents that can be created concurrently."

  validation {
    condition     = var.maximum_concurrency >= 1 && var.maximum_concurrency <= 10000
    error_message = "maximum_concurrency must be between 1 and 10000."
  }
}

variable "agent_mode" {
  type        = string
  default     = "Stateless"
  description = "Agent lifecycle mode. Stateless tears down the agent after every Azure DevOps job."

  validation {
    condition     = contains(["Stateless", "Stateful"], var.agent_mode)
    error_message = "agent_mode must be Stateless or Stateful."
  }
}

variable "automatic_resource_prediction" {
  type = object({
    prediction_preference = optional(string, "Balanced")
  })
  default     = null
  description = "Optional automatic standby-agent prediction configuration. Leave null for no automatic prediction."

  validation {
    condition = var.automatic_resource_prediction == null ? true : contains([
      "MostCostEffective",
      "MoreCostEffective",
      "Balanced",
      "MorePerformance",
      "BestPerformance"
    ], var.automatic_resource_prediction.prediction_preference)
    error_message = "Invalid automatic prediction preference."
  }
}

variable "manual_resource_prediction" {
  type = object({
    all_week_schedule = optional(number)
    time_zone_name    = optional(string, "UTC")
    monday_schedule = optional(list(object({
      count = number
      time  = string
    })), [])
    tuesday_schedule = optional(list(object({
      count = number
      time  = string
    })), [])
    wednesday_schedule = optional(list(object({
      count = number
      time  = string
    })), [])
    thursday_schedule = optional(list(object({
      count = number
      time  = string
    })), [])
    friday_schedule = optional(list(object({
      count = number
      time  = string
    })), [])
    saturday_schedule = optional(list(object({
      count = number
      time  = string
    })), [])
    sunday_schedule = optional(list(object({
      count = number
      time  = string
    })), [])
  })
  default     = null
  description = "Optional manual standby-agent schedule. Leave null for cold-start-only scaling."
}

variable "stateful_grace_period_time_span" {
  type        = string
  default     = "00:00:00"
  description = "How long an idle stateful agent waits for another job before shutdown."
}

variable "stateful_maximum_agent_lifetime" {
  type        = string
  default     = "7.00:00:00"
  description = "Maximum lifetime of a stateful agent before replacement."
}

variable "work_folder" {
  type        = string
  default     = null
  description = "Optional custom work folder used by every agent."
}

##-----------------------------------------------------------------------------
## Managed Identity
##-----------------------------------------------------------------------------
variable "identity_ids" {
  type        = list(string)
  default     = []
  description = "User Assigned Managed Identity IDs assigned to the Managed DevOps Pool."
}

##-----------------------------------------------------------------------------
## Virtual Machine Scale Set Fabric
##-----------------------------------------------------------------------------
variable "sku_name" {
  type        = string
  default     = "Standard_D2ads_v5"
  description = "Azure VM SKU used by Managed DevOps Pool agents."
}

variable "os_disk_storage_account_type" {
  type        = string
  default     = "Standard"
  description = "OS disk type. Supported values are Premium, Standard and StandardSSD."

  validation {
    condition     = contains(["Premium", "Standard", "StandardSSD"], var.os_disk_storage_account_type)
    error_message = "os_disk_storage_account_type must be Premium, Standard or StandardSSD."
  }
}

variable "subnet_id" {
  type        = string
  default     = null
  description = "Dedicated subnet delegated to Microsoft.DevOpsInfrastructure/pools. The subnet and pool must be in the same Azure region."
}

variable "images" {
  type = list(object({
    id                    = optional(string)
    well_known_image_name = optional(string)
    aliases               = optional(list(string), [])
    buffer                = optional(string, "*")
  }))
  default = [
    {
      well_known_image_name = "ubuntu-24.04/latest"
      buffer                = "*"
    }
  ]
  description = "Agent images. Configure exactly one of id or well_known_image_name for each image."

  validation {
    condition     = length(var.images) > 0
    error_message = "At least one agent image must be configured."
  }
}

variable "security" {
  type = object({
    interactive_logon_enabled = optional(bool, false)
    key_vault_management = optional(object({
      key_vault_certificate_ids  = list(string)
      certificate_store_location = optional(string)
      certificate_store_name     = optional(string)
      key_export_enabled         = optional(bool, false)
    }))
  })
  default     = null
  description = "Optional agent security and Key Vault certificate configuration."
}

variable "storage" {
  type = object({
    disk_size_in_gb      = number
    caching              = optional(string)
    drive_letter         = optional(string)
    storage_account_type = optional(string, "Standard_LRS")
  })
  default     = null
  description = "Optional attached data disk configuration for agents."
}

##-----------------------------------------------------------------------------
## Optional VNet Role Assignments
##-----------------------------------------------------------------------------
variable "create_network_role_assignments" {
  type        = bool
  default     = false
  description = "Create Reader and Network Contributor role assignments on the VNet for the DevOpsInfrastructure service principal."
}

variable "virtual_network_id" {
  type        = string
  default     = null
  description = "VNet resource ID used as the scope for optional network role assignments."
}

variable "devops_infrastructure_principal_id" {
  type        = string
  default     = null
  description = "Object ID of the Microsoft DevOpsInfrastructure enterprise application in the tenant."
}