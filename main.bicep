// =====================================================
// Private AKS Cluster with BYO VNET & Entra ID + Azure RBAC
// Uses Azure Verified Module (AVM) for AKS Managed Cluster
// =====================================================

targetScope = 'resourceGroup'

// ========== //
// Parameters //
// ========== //

@description('Required. Name of the AKS cluster.')
param clusterName string

@description('Optional. Azure region for the AKS cluster. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Required. Resource ID of the existing subnet for the system node pool (e.g., /subscriptions/.../subnets/aks-subnet).')
param systemPoolSubnetResourceId string

@description('Optional. Resource ID of the existing subnet for the user node pool. Defaults to the system pool subnet.')
param userPoolSubnetResourceId string = systemPoolSubnetResourceId

@description('Optional. Kubernetes version. If not specified, the latest stable version is used.')
param kubernetesVersion string = ''

@description('Optional. VM size for the system node pool.')
param systemPoolVmSize string = 'Standard_DS4_v2'

@description('Optional. VM size for the user node pool.')
param userPoolVmSize string = 'Standard_DS4_v2'

@description('Optional. Minimum node count for system pool auto-scaler.')
@minValue(1)
param systemPoolMinCount int = 1

@description('Optional. Maximum node count for system pool auto-scaler.')
@minValue(1)
param systemPoolMaxCount int = 3

@description('Optional. Minimum node count for user pool auto-scaler.')
@minValue(1)
param userPoolMinCount int = 1

@description('Optional. Maximum node count for user pool auto-scaler.')
@minValue(1)
param userPoolMaxCount int = 3

@description('Optional. Kubernetes service CIDR. Must not overlap with the VNET address space.')
param serviceCidr string = '10.0.0.0/16'

@description('Optional. DNS service IP. Must be within the serviceCidr range.')
param dnsServiceIP string = '10.0.0.10'

@description('Optional. Resource ID of a private DNS zone for the private cluster (e.g., privatelink.<region>.azmk8s.io). Use "system" for AKS-managed zone or "none" to disable.')
param privateDnsZoneResourceId string = 'system'

@description('Required. Name of the Azure Container Registry.')
param acrName string

@description('Required. Name of the Azure Key Vault.')
param keyVaultName string

@description('Optional. Resource ID of the subnet for ACR and Key Vault private endpoints. Defaults to the system pool subnet.')
param privateEndpointSubnetResourceId string = systemPoolSubnetResourceId

@description('Optional. Resource ID of the private DNS zone for ACR (privatelink.azurecr.io). Leave empty to skip private DNS zone configuration.')
param acrPrivateDnsZoneResourceId string = ''

@description('Optional. Resource ID of the private DNS zone for Key Vault (privatelink.vaultcore.azure.net). Leave empty to skip private DNS zone configuration.')
param keyVaultPrivateDnsZoneResourceId string = ''

@description('Optional. Tags to apply to all resources.')
param tags object = {}

// ============ //
// Deployment   //
// ============ //

// ======================== //
// Azure Container Registry //
// ======================== //

module acr 'br/public:avm/res/container-registry/registry:0.11.0' = {
  name: 'acr-${uniqueString(resourceGroup().id, acrName)}'
  params: {
    name: acrName
    location: location
    tags: tags
    acrSku: 'Premium'
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Enabled'
    privateEndpoints: [
      {
        subnetResourceId: privateEndpointSubnetResourceId
        privateDnsZoneGroup: !empty(acrPrivateDnsZoneResourceId) ? {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: acrPrivateDnsZoneResourceId
            }
          ]
        } : null
      }
    ]
  }
}

// ================ //
// Azure Key Vault   //
// ================ //

module keyVault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: 'kv-${uniqueString(resourceGroup().id, keyVaultName)}'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    privateEndpoints: [
      {
        subnetResourceId: privateEndpointSubnetResourceId
        privateDnsZoneGroup: !empty(keyVaultPrivateDnsZoneResourceId) ? {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
            }
          ]
        } : null
      }
    ]
  }
}

// ============ //
// AKS Cluster  //
// ============ //

module aksCluster 'br/public:avm/res/container-service/managed-cluster:0.13.0' = {
  name: 'aks-${uniqueString(resourceGroup().id, clusterName)}'
  params: {
    name: clusterName
    location: location
    tags: tags

    // --- Managed Identity (System-Assigned) ---
    managedIdentities: {
      systemAssigned: true
    }

    // --- Microsoft Entra ID Authentication with Azure RBAC ---
    aadProfile: {
      enableAzureRBAC: true
      managed: true
    }
    enableRBAC: true
    disableLocalAccounts: true

    // --- OIDC Issuer ---
    enableOidcIssuerProfile: true

    // --- Image Cleaner ---
    securityProfile: {
      imageCleaner: {
        enabled: true
        intervalHours: 48
      }
    }

    // --- Private Cluster ---
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: privateDnsZoneResourceId
    }
    publicNetworkAccess: 'Disabled'

    // --- Azure CNI Networking (BYO VNET) ---
    networkPlugin: 'azure'
    networkPolicy: 'azure'
    serviceCidr: serviceCidr
    dnsServiceIP: dnsServiceIP

    // --- Kubernetes Version ---
    kubernetesVersion: !empty(kubernetesVersion) ? kubernetesVersion : null

    // --- SKU ---
    skuTier: 'Standard'

    // --- Primary (System) Node Pool ---
    primaryAgentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        vmSize: systemPoolVmSize
        vnetSubnetResourceId: systemPoolSubnetResourceId
        availabilityZones: [1, 2, 3]
        enableAutoScaling: true
        minCount: systemPoolMinCount
        maxCount: systemPoolMaxCount
        count: systemPoolMinCount
        maxPods: 30
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        enableNodePublicIP: false
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]

    // --- Secondary (User) Node Pool ---
    agentPools: [
      {
        name: 'userpool'
        mode: 'User'
        vmSize: userPoolVmSize
        vnetSubnetResourceId: userPoolSubnetResourceId
        availabilityZones: [1, 2, 3]
        enableAutoScaling: true
        minCount: userPoolMinCount
        maxCount: userPoolMaxCount
        count: userPoolMinCount
        maxPods: 30
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        enableNodePublicIP: false
        scaleSetPriority: 'Regular'
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]

    // --- Key Vault Secrets Provider CSI Driver ---
    enableKeyvaultSecretsProvider: true
    enableSecretRotation: true

    // --- Azure Policy (enabled by default in AVM) ---
    azurePolicyEnabled: true

    // --- Auto Upgrade ---
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
  }
}

// ====================================== //
// Role Assignments — wire ACR & KV to AKS //
// ====================================== //

// Grant AKS kubelet identity AcrPull on the ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, acrName, clusterName, 'AcrPull')
  scope: acrResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aksCluster.outputs.?kubeletIdentityObjectId ?? ''
    principalType: 'ServicePrincipal'
  }
}

// Reference the deployed ACR to scope the role assignment
resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
  dependsOn: [acr]
}

// Grant AKS Key Vault Secrets Provider identity access to Key Vault secrets
resource kvSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, keyVaultName, clusterName, 'KeyVaultSecretsUser')
  scope: kvResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: aksCluster.outputs.?keyvaultIdentityObjectId ?? ''
    principalType: 'ServicePrincipal'
  }
}

// Reference the deployed Key Vault to scope the role assignment
resource kvResource 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  dependsOn: [keyVault]
}

// ========= //
// Outputs    //
// ========= //

@description('The name of the AKS cluster.')
output clusterName string = aksCluster.outputs.name

@description('The resource ID of the AKS cluster.')
output clusterResourceId string = aksCluster.outputs.resourceId

@description('The control plane FQDN (private) of the AKS cluster.')
output controlPlaneFQDN string = aksCluster.outputs.controlPlaneFQDN

@description('The principal ID of the cluster system-assigned managed identity.')
output systemAssignedIdentityPrincipalId string = aksCluster.outputs.?systemAssignedMIPrincipalId ?? ''

@description('The Object ID of the kubelet identity.')
output kubeletIdentityObjectId string = aksCluster.outputs.?kubeletIdentityObjectId ?? ''

@description('The name of the Azure Container Registry.')
output acrName string = acr.outputs.name

@description('The login server of the Azure Container Registry.')
output acrLoginServer string = acr.outputs.loginServer

@description('The resource ID of the Azure Container Registry.')
output acrResourceId string = acr.outputs.resourceId

@description('The name of the Key Vault.')
output keyVaultName string = keyVault.outputs.name

@description('The resource ID of the Key Vault.')
output keyVaultResourceId string = keyVault.outputs.resourceId

@description('The URI of the Key Vault.')
output keyVaultUri string = keyVault.outputs.uri
