terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  client_id = var.providerInfo["clientID"]
  subscription_id = var.providerInfo["subscriptionID"]
  tenant_id = var.providerInfo["tenantID"]
  features {}
}
