// ===========================================================================
// Module: Key Vault Secrets Role Assignment
// Assigns Key Vault Secrets User role to a principal on a given Key Vault
// ===========================================================================

@description('Name of the Key Vault.')
param keyVaultName string

@description('Principal ID to assign the role to (e.g., AKS managed identity).')
param principalId string

// Built-in Key Vault Secrets User role definition ID
var keyVaultSecretsUserRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
