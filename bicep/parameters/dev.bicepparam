using '../main.bicep'

param environment = 'dev'
param location = 'northeurope'
param keyVaultName = 'mredev-kv-001'
param administratorPrincipalIds = []
param networkAcls = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  ipRules: []
  virtualNetworkRules: []
}
param tags = {
  project: 'KeyVaultIaC'
  environment: 'dev'
  costCenter: 'IT'
}
