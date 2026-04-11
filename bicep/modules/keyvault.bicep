@description('Name of the Key Vault instance.')
param keyVaultName string

@description('Azure location for the Key Vault.')
param location string = resourceGroup().location

@description('Tenant ID used by the Key Vault.')
param tenantId string = tenant().tenantId

@description('Key Vault SKU name.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Enable soft delete for the Key Vault.')
param enableSoftDelete bool = true

@description('Soft delete retention in days.')
@minValue(7)
@maxValue(365)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection for the Key Vault.')
param enablePurgeProtection bool = true

@description('Enable RBAC authorization for Key Vault data plane access.')
param enableRbacAuthorization bool = true

@description('Public network access setting for Key Vault.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Network ACL configuration for Key Vault.')
param networkAcls object = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  ipRules: []
  virtualNetworkRules: []
}

@description('Optional list of principal object IDs to assign Key Vault Administrator role.')
param administratorPrincipalIds array = []

@description('Tags applied to the Key Vault.')
param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    enableRbacAuthorization: enableRbacAuthorization
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in administratorPrincipalIds: if (principalId != '') {
    name: guid(keyVault.id, principalId, 'KeyVaultAdmin')
    scope: keyVault
    properties: {
      roleDefinitionId: tenantResourceId(
        'Microsoft.Authorization/roleDefinitions',
        'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
      )
      principalId: principalId
    }
  }
]

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
