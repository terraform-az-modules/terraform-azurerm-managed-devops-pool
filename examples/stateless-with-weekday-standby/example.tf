##-----------------------------------------------------------------------------
## Provider
##-----------------------------------------------------------------------------
provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current_client_config" {}

locals {
  name        = "core"
  environment = "test"
  location    = "centralus"
  label_order = ["name", "environment", "location"]
}

##-----------------------------------------------------------------------------
## Resource Group (Optional - only create if resource_group_name is null)
##-----------------------------------------------------------------------------
module "resource_group" {
  source  = "terraform-az-modules/resource-group/azurerm"
  version = "1.0.3"

  name        = local.name
  environment = local.environment
  label_order = local.label_order
  location    = local.location
}

##-----------------------------------------------------------------------------
## Virtual Network
##-----------------------------------------------------------------------------
module "vnet" {
  source  = "terraform-az-modules/vnet/azurerm"
  version = "1.0.3"

  name                = local.name
  environment         = local.environment
  label_order         = local.label_order
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  address_spaces      = ["10.0.0.0/16"]
}

##-----------------------------------------------------------------------------
## Subnet with Delegation for DevOps Infrastructure
##-----------------------------------------------------------------------------
module "subnet" {
  source  = "terraform-az-modules/subnet/azurerm"
  version = "1.0.1"

  environment          = local.environment
  label_order          = local.label_order
  resource_group_name  = module.resource_group.resource_group_name
  location             = module.resource_group.resource_group_location
  virtual_network_name = module.vnet.vnet_name

  subnets = [
    {
      name            = "devops-pool-subnet"
      subnet_prefixes = ["10.0.1.0/24"]
      delegations = [
        {
          name = "devopsInfrastructureDelegation"
          service_delegations = [{
            name    = "Microsoft.DevOpsInfrastructure/pools"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }]
        }
      ]
    }
  ]
}

##-----------------------------------------------------------------------------
## Stateless Pool with One Standby Agent During Weekday Working Hours
##-----------------------------------------------------------------------------
module "managed-devops-pool" {
  source = "../../"

  name                = "test-2"
  environment         = "shared"
  location            = "centralus"
  label_order         = ["name", "environment", "location"]
  resource_group_name = "rg-test-network-cus"

  custom_managed_devops_pool_name = "test-2-managed-pool"

  maximum_concurrency = 1
  agent_mode          = "Stateless"

  azure_devops_organizations = [
    {
      url         = "https://dev.azure.com/clouddrove-sandbox-2"
      parallelism = 1
      projects    = ["sandbox-2"]
    }
  ]

  create_network_role_assignments    = true
  virtual_network_id                 = module.vnet.vnet_id
  devops_infrastructure_principal_id = "b757d60a-8f90-4d08-8e8a-42f409556141"
  manual_resource_prediction = {
    time_zone_name = "India Standard Time"

    monday_schedule = [
      { count = 1, time = "08:00:00" },
      { count = 0, time = "22:00:00" }
    ]
    tuesday_schedule = [
      { count = 1, time = "08:00:00" },
      { count = 0, time = "22:00:00" }
    ]
    wednesday_schedule = [
      { count = 1, time = "08:00:00" },
      { count = 0, time = "22:00:00" }
    ]
    thursday_schedule = [
      { count = 1, time = "08:00:00" },
      { count = 0, time = "22:00:00" }
    ]
    friday_schedule = [
      { count = 1, time = "08:00:00" },
      { count = 0, time = "22:00:00" }
    ]
  }
}
