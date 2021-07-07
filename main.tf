# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }

    ## Have to add the below line to download dependencies for databricks
    ## https://stackoverflow.com/questions/66015148/terraform-unable-to-list-provider

    databricks = {
      source  = "databrickslabs/databricks"
      version = "0.3.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

## Resource Group
resource "azurerm_resource_group" "ref-rgypd" {
  name     = "rgypd"
  location = "West Europe"

  tags = {
    environment = "dev"
  }
}

## Blob Storage Account
resource "azurerm_storage_account" "ref-strgblobypd" {
  name                     = "strgblobypd"
  resource_group_name      = azurerm_resource_group.ref-rgypd.name
  location                 = azurerm_resource_group.ref-rgypd.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "dev"
  }
}

## Blob Storage Account Container
resource "azurerm_storage_container" "ref-strgblobcntrypd" {
  name                  = "strgblobcntrypd"
  storage_account_name  = azurerm_storage_account.ref-strgblobypd.name
  container_access_type = "private"
}

## Data lake Storage
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_data_lake_gen2_filesystem
## Open ISSUE
## https://github.com/terraform-providers/terraform-provider-azurerm/issues/6659
## Unable to resolve.So workaround is:- 
## Add the "contributor" role to the user in the resource group
## When we execute from terraform then the local user is used. This local user doesnot have "contributor"
## permmisons. Hence we need to  add the "contributor" role to the user in the resource group
resource "azurerm_storage_account" "ref-strgdlypd" {
  name                     = "strgdlypd"
  resource_group_name      = azurerm_resource_group.ref-rgypd.name
  location                 = azurerm_resource_group.ref-rgypd.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"

  tags = {
    environment = "dev"
  }

}

## Data lake Storage file system
resource "azurerm_storage_data_lake_gen2_filesystem" "ref-strgdlypd" {
  name               = "ref-strgdlypd"
  storage_account_id = azurerm_storage_account.ref-strgdlypd.id
}

#Postgre SQL Server
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_server
resource "azurerm_postgresql_server" "ref-psqlserverypd" {
  name                = "psqlserverypd"
  location            = azurerm_resource_group.ref-rgypd.location
  resource_group_name =  azurerm_resource_group.ref-rgypd.name

  administrator_login          = "adminypd"
  administrator_login_password = "Welcome@2021"

  sku_name   = "GP_Gen5_4"
  version    = "9.6"
  storage_mb = 640000

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

# Postgre sql db
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_database
resource "azurerm_postgresql_database" "ref-psqldbypd" {
  name                = "psqldbypd"
  resource_group_name = azurerm_resource_group.ref-rgypd.name
  server_name         = azurerm_postgresql_server.ref-psqlserverypd.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# ADF
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/data_factory

resource "azurerm_data_factory" "ref-adfypd" {
  name                = "adfypd"
  location            = azurerm_resource_group.ref-rgypd.location
  resource_group_name = azurerm_resource_group.ref-rgypd.name

tags = {
    environment = "dev"
  }

}


# SQL Server
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sql_server
resource "azurerm_sql_server" "ref-sqlsrvrypd" {
  name                         = "sqlsrvrypd"
  resource_group_name          = azurerm_resource_group.ref-rgypd.name
  location                     = azurerm_resource_group.ref-rgypd.location
  version                      = "12.0"
  administrator_login          = "adminsqlsrvrypd"
  administrator_login_password = "Welcome@2021"


  tags = {
    environment = "dev"
  }
}

# Create a data source
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/sql_server
#data "azurerm_sql_server" "ref-data_sqlsrvrypd" {
#  name                = azurerm_sql_server.ref-sqlsrvrypd.name
#  resource_group_name = azurerm_resource_group.ref-rgypd.name
#}

#Firewall Rules
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sql_firewall_rule
resource "azurerm_sql_firewall_rule" "ref-sqlfwlruleypd" {
  name                = "sqlfwlruleypd"
  resource_group_name = azurerm_resource_group.ref-rgypd.name
  server_name         = azurerm_sql_server.ref-sqlsrvrypd.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"

  depends_on = [
    azurerm_sql_server.ref-sqlsrvrypd
  ]
}

#SQL database
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sql_database
resource "azurerm_sql_database" "ref-sqldbypd" {
  name                = "sqldbypd"
  resource_group_name = azurerm_resource_group.ref-rgypd.name
  location            = azurerm_resource_group.ref-rgypd.location
  server_name         = azurerm_sql_server.ref-sqlsrvrypd.name
  edition = "Standard"
  requested_service_objective_name = "S0"

  depends_on = [
    azurerm_sql_server.ref-sqlsrvrypd
  ]

  tags = {
    environment = "dev"
  }
}

#Databricks Spark Cluster

## Workspace Creation
## https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_workspace
resource "azurerm_databricks_workspace" "ref-databrckswspcypd" {
  name                = "databrckswspcypd"
  resource_group_name = azurerm_resource_group.ref-rgypd.name
  location            = azurerm_resource_group.ref-rgypd.location
  sku                 = "premium"

  tags = {
    Environment = "dev"
  }
}

# # Configure the Databricks Provider
#  provider "databricks" {
#   azure_workspace_resource_id = azurerm_databricks_workspace.ref-databrckswspcypd.id
#  }

# ## Spark Cluster
# ## https://registry.terraform.io/providers/databrickslabs/databricks/latest/docs/resources/cluster
# data "databricks_node_type" "smallest" {
#   local_disk = true
#   depends_on = [
#     azurerm_databricks_workspace.ref-databrckswspcypd
#   ]
# }

# data "databricks_spark_version" "latest_lts" {
#   long_term_support = true
#   depends_on = [
#     azurerm_databricks_workspace.ref-databrckswspcypd
#   ]
# }

# resource "time_sleep" "ref-wait90secypd" {
#     depends_on = [
#     data.databricks_node_type.smallest,
#     data.databricks_spark_version.latest_lts
#   ]
# create_duration = "90s"
# }

# resource "databricks_cluster" "ref-databrcksclstrypd" {
#   cluster_name            = "databrcksclstrypd"
#   spark_version           = data.databricks_spark_version.latest_lts.id
#   node_type_id            = data.databricks_node_type.smallest.id
#   autotermination_minutes = 10
  
#   ## Doesnot work as it is a free subscription
#   ## Error: Error: 0627-080426-atoll278 is not able to transition from TERMINATED to RUNNING: The operation could not be performed on your account with the 
#   ## following error message:  azure_error_code: OperationNotAllowed, azure_error_message: Operation could not be completed as it results in.... Please see https://docs.databricks.com/dev-tools/api/latest/clusters.html#clusterclusterstate for more details
#   ## with databricks_cluster.ref-databrcksclstrypd,
#   ## on main.tf line 227, in resource "databricks_cluster" "ref-databrcksclstrypd":
#   ## 227: resource "databricks_cluster" "ref-databrcksclstrypd" {

#   ## TODO Try executing the same after you account upgrade  

#   autoscale {
#     min_workers = 1
#     max_workers = 2
#   }

#   depends_on = [
#     time_sleep.ref-wait90secypd
#   ]

# }