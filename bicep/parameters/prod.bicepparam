using '../main.bicep'

param environment = 'prod'
param location = 'northeurope'
param keyVaultName = 'mreprod-kv-001'
param administratorPrincipalIds = []
param networkAcls = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  ipRules: []
  virtualNetworkRules: []
}
param tags = {
  project: 'KeyVaultIaC'
  businessUnit: 'Risk'
  costCenter: 'IT'
}
