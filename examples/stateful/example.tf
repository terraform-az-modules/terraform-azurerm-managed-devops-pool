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
## Stateless Managed DevOps Pool for Private AKS and ACR
##-----------------------------------------------------------------------------
module "managed-devops-pool" {
  source = "../../"

  name                = "test"
  environment         = "shared"
  location            = "centralus"
  label_order         = ["name", "environment", "location"]
  resource_group_name = "rg-test-network-cus"

  custom_dev_center_name             = "test-shared"
  custom_dev_center_project_name     = "test-shared"
  custom_managed_devops_pool_name    = "test-managed-pool-1"
  create_network_role_assignments    = true
  virtual_network_id                 = module.vnet.vnet_id
  devops_infrastructure_principal_id = "b757d60a-8f90-4d08-8e8a-42f409556141"
  maximum_concurrency                = 1
  agent_mode                         = "Stateful"

  azure_devops_organizations = [
    {
      url         = "https://dev.azure.com/clouddrove-sandbox-2"
      parallelism = 1
      projects    = ["sandbox-2"]
    }
  ]

  subnet_id = module.subnet.subnet_ids.devops-pool-subnet
  sku_name  = "Standard_D2ads_v5"

  images = [
    {
      well_known_image_name = "ubuntu-24.04/latest"
      buffer                = "*"
    }
  ]

  extra_tags = {
    Purpose = "Private AKS and ACR deployment agents"
  }
}
