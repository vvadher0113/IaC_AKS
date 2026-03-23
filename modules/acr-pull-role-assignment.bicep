@description('Assign AcrPull role to a principal on a given ACR')
param acrName string
param principalId string
param roleAssignmentName string = guid(acrName, principalId, 'acrpull')

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
