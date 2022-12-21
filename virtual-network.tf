resource "azurerm_virtual_network" "default" {
  count = local.existing_virtual_network == "" ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  name                = "${local.resource_prefix}default"
  address_space       = [local.virtual_network_address_space]
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_route_table" "default" {
  count = local.launch_in_vnet ? 1 : 0

  name                          = "${local.resource_prefix}default"
  location                      = local.resource_group.location
  resource_group_name           = local.resource_group.name
  disable_bgp_route_propagation = false
  tags                          = local.tags
}

resource "azurerm_subnet" "container_apps_infra_subnet" {
  count = local.launch_in_vnet ? 1 : 0

  name                 = "${local.resource_prefix}containerappsinfra"
  virtual_network_name = local.virtual_network.name
  resource_group_name  = local.resource_group.name
  address_prefixes     = [local.container_apps_infra_subnet_cidr]
}

resource "azurerm_subnet_route_table_association" "container_apps_infra_subnet" {
  count = local.launch_in_vnet ? 1 : 0

  subnet_id      = azurerm_subnet.container_apps_infra_subnet[0].id
  route_table_id = azurerm_route_table.default[0].id
}

resource "azurerm_network_security_group" "container_apps_infra_allow_frontdoor_inbound_only" {
  count = local.launch_in_vnet && local.restrict_container_apps_to_cdn_inbound_only && local.enable_cdn_frontdoor ? 1 : 0

  name                = "${local.resource_prefix}containerappsinfransg"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name

  security_rule {
    name                       = "AllowFrontdoor"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureFrontDoor.Backend"
    destination_address_prefix = "${jsondecode(azapi_resource.container_app_env.output).properties.staticIp}/32"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "container_apps_infra_allow_frontdoor_inbound_only" {
  count = local.launch_in_vnet && local.restrict_container_apps_to_cdn_inbound_only && local.enable_cdn_frontdoor ? 1 : 0

  subnet_id                 = azurerm_subnet.container_apps_infra_subnet[0].id
  network_security_group_id = azurerm_network_security_group.container_apps_infra_allow_frontdoor_inbound_only[0].id
}

resource "azurerm_subnet" "redis_cache_subnet" {
  count = local.launch_in_vnet ? (
    local.redis_cache_sku == "Premium" ? 1 : 0
  ) : 0

  name                 = "${local.resource_prefix}rediscache"
  virtual_network_name = local.virtual_network.name
  resource_group_name  = local.resource_group.name
  address_prefixes     = [local.redis_cache_subnet_cidr]
}

resource "azurerm_subnet_route_table_association" "redis_cache_subnet" {
  count = local.launch_in_vnet ? (
    local.redis_cache_sku == "Premium" ? 1 : 0
  ) : 0

  subnet_id      = azurerm_subnet.redis_cache_subnet[0].id
  route_table_id = azurerm_route_table.default[0].id
}

resource "azurerm_subnet" "mssql_private_endpoint_subnet" {
  count = local.enable_mssql_database ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  name                                      = "${local.resource_prefix}mssqlprivateendpoint"
  virtual_network_name                      = local.virtual_network.name
  resource_group_name                       = local.resource_group.name
  address_prefixes                          = [local.mssql_private_endpoint_subnet_cidr]
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet_route_table_association" "mssql_private_endpoint_subnet" {
  count = local.enable_mssql_database ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  subnet_id      = azurerm_subnet.mssql_private_endpoint_subnet[0].id
  route_table_id = azurerm_route_table.default[0].id
}

resource "azurerm_private_dns_zone" "mssql_private_link" {
  count = local.enable_mssql_database ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  name                = "${local.resource_prefix}.database.windows.net"
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mssql_private_link" {
  count = local.enable_mssql_database ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  name                  = "${local.resource_prefix}mssqlprivatelink"
  resource_group_name   = local.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.mssql_private_link[0].name
  virtual_network_id    = local.virtual_network.id
  tags                  = local.tags
}

resource "azurerm_subnet" "redis_cache_private_endpoint_subnet" {
  count = local.enable_redis_cache ? (
    local.launch_in_vnet ? (
      local.redis_cache_sku == "Premium" ? 1 : 0
    ) : 0
  ) : 0

  name                                      = "${local.resource_prefix}rediscacheprivateendpoint"
  virtual_network_name                      = local.virtual_network.name
  resource_group_name                       = local.resource_group.name
  address_prefixes                          = [local.redis_cache_private_endpoint_subnet_cidr]
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet_route_table_association" "redis_cache_private_endpoint_subnet" {
  count = local.enable_redis_cache ? (
    local.launch_in_vnet ? (
      local.redis_cache_sku == "Premium" ? 1 : 0
    ) : 0
  ) : 0

  subnet_id      = azurerm_subnet.redis_cache_private_endpoint_subnet[0].id
  route_table_id = azurerm_route_table.default[0].id
}

resource "azurerm_private_dns_zone" "redis_cache_private_link" {
  count = local.enable_redis_cache ? (
    local.launch_in_vnet ? (
      local.redis_cache_sku == "Premium" ? 1 : 0
    ) : 0
  ) : 0

  name                = "${local.resource_prefix}.redis.cache.windows.net"
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis_cache_private_link" {
  count = local.enable_redis_cache ? (
    local.launch_in_vnet ? (
      local.redis_cache_sku == "Premium" ? 1 : 0
    ) : 0
  ) : 0

  name                  = "${local.resource_prefix}rediscacheprivatelink"
  resource_group_name   = local.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.redis_cache_private_link[0].name
  virtual_network_id    = local.virtual_network.id
  tags                  = local.tags
}

resource "azurerm_subnet" "container_instances_subnet" {
  count = local.enable_mssql_database ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  name                                      = "${local.resource_prefix}containerinstances"
  virtual_network_name                      = local.virtual_network.name
  resource_group_name                       = local.resource_group.name
  address_prefixes                          = [local.container_instances_subnet_cidr]
  private_endpoint_network_policies_enabled = true

  delegation {
    name = "ACIDelegationService"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
      name = "Microsoft.ContainerInstance/containerGroups"
    }
  }
}

resource "azurerm_subnet_route_table_association" "containerinstances_subnet" {
  count = local.enable_mssql_database ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  subnet_id      = azurerm_subnet.container_instances_subnet[0].id
  route_table_id = azurerm_route_table.default[0].id
}
