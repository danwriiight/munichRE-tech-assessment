using '../main.bicep'

param environment = 'test'
param location = 'northeurope'
param keyVaultName = 'mretest-kv-001'
param administratorPrincipalIds = []
param networkAcls = {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
  ipRules: []
  virtualNetworkRules: []
}
param tags = {
  project: 'KeyVaultIaC'
  environment: 'test'
  costCenter: 'IT'
}
