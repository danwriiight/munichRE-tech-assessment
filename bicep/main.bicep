@description('Deployment environment name.')
param environment string

@description('Azure location for the deployment.')
param location string = resourceGroup().location

@description('Key Vault name. Must be unique within the resource group.')
param keyVaultName string

@description('Tenant ID used by the Key Vault.')
param tenantId string = tenant().tenantId

@description('Object IDs of principals that should receive Key Vault Administrator RBAC.')
param administratorPrincipalIds array = []

@description('Network ACLs for the Key Vault.')
param networkAcls object = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  ipRules: []
  virtualNetworkRules: []
}

@description('Tags to apply to all Key Vault resources.')
param tags object = {}

var baseTags = union(tags, {
  environment: environment
  deployedBy: 'Bicep'
  solution: 'KeyVaultIaC'
})

module keyVaultModule 'modules/keyvault.bicep' = {
  name: 'keyVaultModule'
  params: {
    keyVaultName: keyVaultName
    location: location
    tenantId: tenantId
    skuName: 'standard'
    enableSoftDelete: true
    softDeleteRetentionInDays: 30
    enablePurgeProtection: true
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    networkAcls: networkAcls
    administratorPrincipalIds: administratorPrincipalIds
    tags: baseTags
  }
}

output keyVaultResourceId string = keyVaultModule.outputs.keyVaultId
output keyVaultNameOutput string = keyVaultModule.outputs.keyVaultName
