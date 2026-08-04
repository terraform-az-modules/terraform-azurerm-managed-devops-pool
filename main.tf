##-----------------------------------------------------------------------------
## Standard Tagging Module - Applies standard tags to all resources
##-----------------------------------------------------------------------------
module "labels" {
  source          = "terraform-az-modules/tags/azurerm"
  version         = "1.0.2"
  name            = var.custom_name == null ? var.name : var.custom_name
  location        = var.location
  environment     = var.environment
  managedby       = var.managedby
  label_order     = var.label_order
  repository      = var.repository
  deployment_mode = var.deployment_mode
  extra_tags      = var.extra_tags
}

##-----------------------------------------------------------------------------
## Input Validation
##-----------------------------------------------------------------------------
resource "terraform_data" "validation" {
  count = var.enable ? 1 : 0

  input = local.managed_devops_pool_name

  lifecycle {
    precondition {
      condition = !var.create_dev_center_project || (
        var.create_dev_center || var.dev_center_id != null
      )
      error_message = "dev_center_id must be provided when create_dev_center_project is true and create_dev_center is false."
    }

    precondition {
      condition     = var.create_dev_center_project || var.dev_center_project_id != null
      error_message = "dev_center_project_id must be provided when create_dev_center_project is false."
    }

    precondition {
      condition     = length(var.azure_devops_organizations) > 0
      error_message = "At least one Azure DevOps organization must be configured."
    }

    precondition {
      condition = sum([
        for organization in var.azure_devops_organizations : organization.parallelism
      ]) == var.maximum_concurrency
      error_message = "The sum of organization.parallelism values must equal maximum_concurrency."
    }

    precondition {
      condition = !(
        var.automatic_resource_prediction != null &&
        var.manual_resource_prediction != null
      )
      error_message = "Only one of automatic_resource_prediction or manual_resource_prediction can be configured."
    }

    precondition {
      condition = alltrue([
        for image in var.images : (
          (try(image.id, null) != null) !=
          (try(image.well_known_image_name, null) != null)
        )
      ])
      error_message = "Each image must configure exactly one of id or well_known_image_name."
    }

    precondition {
      condition     = length(local.managed_devops_pool_name) >= 3 && length(local.managed_devops_pool_name) <= 44
      error_message = "Managed DevOps Pool name must contain between 3 and 44 characters."
    }

    precondition {
      condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9-]$", local.managed_devops_pool_name))
      error_message = "Managed DevOps Pool name must start with an alphanumeric character, contain only alphanumeric characters, periods or hyphens, and must not end with a period."
    }

    precondition {
      condition = try(var.azure_devops_permission.kind, "Inherit") != "SpecificAccounts" || (
        try(var.azure_devops_permission.administrator_account, null) != null &&
        (
          length(try(var.azure_devops_permission.administrator_account.groups, [])) > 0 ||
          length(try(var.azure_devops_permission.administrator_account.users, [])) > 0
        )
      )
      error_message = "SpecificAccounts permission requires at least one administrator group or user."
    }

    precondition {
      condition = var.manual_resource_prediction == null ? true : (
        var.manual_resource_prediction.all_week_schedule != null ||
        length(var.manual_resource_prediction.monday_schedule) > 0 ||
        length(var.manual_resource_prediction.tuesday_schedule) > 0 ||
        length(var.manual_resource_prediction.wednesday_schedule) > 0 ||
        length(var.manual_resource_prediction.thursday_schedule) > 0 ||
        length(var.manual_resource_prediction.friday_schedule) > 0 ||
        length(var.manual_resource_prediction.saturday_schedule) > 0 ||
        length(var.manual_resource_prediction.sunday_schedule) > 0
      )
      error_message = "manual_resource_prediction requires all_week_schedule or at least one daily schedule."
    }

    precondition {
      condition = var.manual_resource_prediction == null ? true : !(
        var.manual_resource_prediction.all_week_schedule != null &&
        (
          length(var.manual_resource_prediction.monday_schedule) > 0 ||
          length(var.manual_resource_prediction.tuesday_schedule) > 0 ||
          length(var.manual_resource_prediction.wednesday_schedule) > 0 ||
          length(var.manual_resource_prediction.thursday_schedule) > 0 ||
          length(var.manual_resource_prediction.friday_schedule) > 0 ||
          length(var.manual_resource_prediction.saturday_schedule) > 0 ||
          length(var.manual_resource_prediction.sunday_schedule) > 0
        )
      )
      error_message = "manual_resource_prediction cannot combine all_week_schedule with individual daily schedules."
    }

    precondition {
      condition = !var.create_network_role_assignments || (
        var.virtual_network_id != null &&
        var.devops_infrastructure_principal_id != null
      )
      error_message = "virtual_network_id and devops_infrastructure_principal_id are required when create_network_role_assignments is true."
    }
  }
}

##-----------------------------------------------------------------------------
## Dev Center
##-----------------------------------------------------------------------------
resource "azurerm_dev_center" "default" {
  count = var.enable && var.create_dev_center ? 1 : 0

  name                              = local.dev_center_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  project_catalog_item_sync_enabled = var.project_catalog_item_sync_enabled
  tags                              = module.labels.tags

  dynamic "identity" {
    for_each = var.dev_center_identity != null ? [var.dev_center_identity] : []

    content {
      type         = identity.value.type
      identity_ids = length(identity.value.identity_ids) > 0 ? identity.value.identity_ids : null
    }
  }

  depends_on = [terraform_data.validation]
}

##-----------------------------------------------------------------------------
## Dev Center Project
##-----------------------------------------------------------------------------
resource "azurerm_dev_center_project" "default" {
  count = var.enable && var.create_dev_center_project ? 1 : 0

  name                       = local.dev_center_project_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  dev_center_id              = local.dev_center_id
  description                = var.dev_center_project_description
  maximum_dev_boxes_per_user = var.maximum_dev_boxes_per_user
  tags                       = module.labels.tags

  dynamic "identity" {
    for_each = var.dev_center_project_identity != null ? [var.dev_center_project_identity] : []

    content {
      type         = identity.value.type
      identity_ids = length(identity.value.identity_ids) > 0 ? identity.value.identity_ids : null
    }
  }

  depends_on = [terraform_data.validation]
}

##-----------------------------------------------------------------------------
## Managed DevOps Pool
##-----------------------------------------------------------------------------
resource "azurerm_managed_devops_pool" "default" {
  count = var.enable ? 1 : 0

  name                  = local.managed_devops_pool_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  dev_center_project_id = local.dev_center_project_id
  maximum_concurrency   = var.maximum_concurrency
  work_folder           = var.work_folder
  tags                  = module.labels.tags

  azure_devops_organization {
    dynamic "organization" {
      for_each = var.azure_devops_organizations

      content {
        url         = organization.value.url
        parallelism = organization.value.parallelism
        projects    = try(organization.value.projects, null)
      }
    }

    dynamic "permission" {
      for_each = var.azure_devops_permission != null ? [var.azure_devops_permission] : []

      content {
        kind = permission.value.kind

        dynamic "administrator_account" {
          for_each = permission.value.administrator_account != null ? [permission.value.administrator_account] : []

          content {
            groups = length(administrator_account.value.groups) > 0 ? administrator_account.value.groups : null
            users  = length(administrator_account.value.users) > 0 ? administrator_account.value.users : null
          }
        }
      }
    }
  }

  dynamic "identity" {
    for_each = length(var.identity_ids) > 0 ? [1] : []

    content {
      type         = "UserAssigned"
      identity_ids = var.identity_ids
    }
  }

  dynamic "stateless_agent" {
    for_each = var.agent_mode == "Stateless" ? [1] : []

    content {
      dynamic "automatic_resource_prediction" {
        for_each = var.automatic_resource_prediction != null ? [var.automatic_resource_prediction] : []

        content {
          prediction_preference = automatic_resource_prediction.value.prediction_preference
        }
      }

      dynamic "manual_resource_prediction" {
        for_each = var.manual_resource_prediction != null ? [var.manual_resource_prediction] : []

        content {
          all_week_schedule = manual_resource_prediction.value.all_week_schedule
          time_zone_name    = manual_resource_prediction.value.time_zone_name

          dynamic "monday_schedule" {
            for_each = manual_resource_prediction.value.monday_schedule
            content {
              count = monday_schedule.value.count
              time  = monday_schedule.value.time
            }
          }

          dynamic "tuesday_schedule" {
            for_each = manual_resource_prediction.value.tuesday_schedule
            content {
              count = tuesday_schedule.value.count
              time  = tuesday_schedule.value.time
            }
          }

          dynamic "wednesday_schedule" {
            for_each = manual_resource_prediction.value.wednesday_schedule
            content {
              count = wednesday_schedule.value.count
              time  = wednesday_schedule.value.time
            }
          }

          dynamic "thursday_schedule" {
            for_each = manual_resource_prediction.value.thursday_schedule
            content {
              count = thursday_schedule.value.count
              time  = thursday_schedule.value.time
            }
          }

          dynamic "friday_schedule" {
            for_each = manual_resource_prediction.value.friday_schedule
            content {
              count = friday_schedule.value.count
              time  = friday_schedule.value.time
            }
          }

          dynamic "saturday_schedule" {
            for_each = manual_resource_prediction.value.saturday_schedule
            content {
              count = saturday_schedule.value.count
              time  = saturday_schedule.value.time
            }
          }

          dynamic "sunday_schedule" {
            for_each = manual_resource_prediction.value.sunday_schedule
            content {
              count = sunday_schedule.value.count
              time  = sunday_schedule.value.time
            }
          }
        }
      }
    }
  }

  dynamic "stateful_agent" {
    for_each = var.agent_mode == "Stateful" ? [1] : []

    content {
      grace_period_time_span = var.stateful_grace_period_time_span
      maximum_agent_lifetime = var.stateful_maximum_agent_lifetime

      dynamic "automatic_resource_prediction" {
        for_each = var.automatic_resource_prediction != null ? [var.automatic_resource_prediction] : []

        content {
          prediction_preference = automatic_resource_prediction.value.prediction_preference
        }
      }

      dynamic "manual_resource_prediction" {
        for_each = var.manual_resource_prediction != null ? [var.manual_resource_prediction] : []

        content {
          all_week_schedule = manual_resource_prediction.value.all_week_schedule
          time_zone_name    = manual_resource_prediction.value.time_zone_name

          dynamic "monday_schedule" {
            for_each = manual_resource_prediction.value.monday_schedule
            content {
              count = monday_schedule.value.count
              time  = monday_schedule.value.time
            }
          }

          dynamic "tuesday_schedule" {
            for_each = manual_resource_prediction.value.tuesday_schedule
            content {
              count = tuesday_schedule.value.count
              time  = tuesday_schedule.value.time
            }
          }

          dynamic "wednesday_schedule" {
            for_each = manual_resource_prediction.value.wednesday_schedule
            content {
              count = wednesday_schedule.value.count
              time  = wednesday_schedule.value.time
            }
          }

          dynamic "thursday_schedule" {
            for_each = manual_resource_prediction.value.thursday_schedule
            content {
              count = thursday_schedule.value.count
              time  = thursday_schedule.value.time
            }
          }

          dynamic "friday_schedule" {
            for_each = manual_resource_prediction.value.friday_schedule
            content {
              count = friday_schedule.value.count
              time  = friday_schedule.value.time
            }
          }

          dynamic "saturday_schedule" {
            for_each = manual_resource_prediction.value.saturday_schedule
            content {
              count = saturday_schedule.value.count
              time  = saturday_schedule.value.time
            }
          }

          dynamic "sunday_schedule" {
            for_each = manual_resource_prediction.value.sunday_schedule
            content {
              count = sunday_schedule.value.count
              time  = sunday_schedule.value.time
            }
          }
        }
      }
    }
  }

  virtual_machine_scale_set_fabric {
    sku_name                     = var.sku_name
    os_disk_storage_account_type = var.os_disk_storage_account_type
    subnet_id                    = var.subnet_id

    dynamic "image" {
      for_each = var.images

      content {
        id                    = try(image.value.id, null)
        well_known_image_name = try(image.value.well_known_image_name, null)
        aliases               = length(try(image.value.aliases, [])) > 0 ? image.value.aliases : null
        buffer                = try(image.value.buffer, "*")
      }
    }

    dynamic "security" {
      for_each = var.security != null ? [var.security] : []

      content {
        interactive_logon_enabled = security.value.interactive_logon_enabled

        dynamic "key_vault_management" {
          for_each = security.value.key_vault_management != null ? [security.value.key_vault_management] : []

          content {
            key_vault_certificate_ids  = key_vault_management.value.key_vault_certificate_ids
            certificate_store_location = key_vault_management.value.certificate_store_location
            certificate_store_name     = key_vault_management.value.certificate_store_name
            key_export_enabled         = key_vault_management.value.key_export_enabled
          }
        }
      }
    }

    dynamic "storage" {
      for_each = var.storage != null ? [var.storage] : []

      content {
        disk_size_in_gb      = storage.value.disk_size_in_gb
        caching              = storage.value.caching
        drive_letter         = storage.value.drive_letter
        storage_account_type = storage.value.storage_account_type
      }
    }
  }

  depends_on = [
    terraform_data.validation,
    azurerm_role_assignment.devops_infrastructure_reader,
    azurerm_role_assignment.devops_infrastructure_network_contributor
  ]
}
