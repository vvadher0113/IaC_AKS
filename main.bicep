// =====================================================
// Private AKS Cluster with BYO VNET & Entra ID + Azure RBAC
// Uses Azure Verified Module (AVM) for AKS Managed Cluster
// =====================================================

targetScope = 'subscription'

// ===========================================================================================================================================
// Parameters 
// ===========================================================================================================================================

@description('Optional. Azure region for the AKS cluster. Defaults to the resource group location.')
param location string 

@description('Required. Subscription ID where the AKS cluster will be deployed.')
param SubscriptionId string 

@description('Optional. Tags to apply to all resources.')
param tags object = {}

//============================================================================================================================================
//Feature Flags
//============================================================================================================================================
@description('Optional. Flag to enable deployment of a new VNET for the AKS cluster. Defaults to true. If false, existing subnets must be provided for node pools and private endpoints.')
param deployVNet bool = true

@description('Optional. Flag to enable deployment of a Log Analytics Workspace for AKS monitoring. Defaults to true.')
param deployLogAnalyticsWorkspace bool = true

@description('Optional. Flag to enable deployment of an Azure Key Vault for AKS secrets management. Defaults to true.')
param deployKeyVault bool = true


@description('Optional. Flag to enable deployment of a Key Vault private endpoint. Defaults to true.')
param deployKeyVaultPrivateEndpoint bool = true

@description('Optional. Flag to enable deployment of Key Vault role assignment for AKS managed identity. Defaults to false.')
param deployKeyVaultRoleAssignment bool = false

@description('Optional. Flag to enable deployment of ACR role assignment for AKS managed identity. Defaults to false.')
param deployAcrRoleAssignment bool = false

@description('Optional. Flag to enable deployment of an Azure Container Registry for AKS image storage. Defaults to true.')
param deployAcr bool = true

@description('Optional. Flag to enable deployment of an ACR private endpoint. Defaults to true.')
param deployAcrPrivateEndpoint bool = true

@description('Optional. Flag to enable deployment of the AKS cluster. Defaults to true.')
param deployAksCluster bool = true

// ===========================================================================================================================================
//Azure Resource Naming Parameters
//============================================================================================================================================
@description('Required. Name of the resource group where all resources will be deployed.')
param resourceGroupName string

@description('Required. Name of the virtual network.')
param vnetName string 

@description('Required if deployLogAnalyticsWorkspace is true. Name of the Log Analytics Workspace for AKS monitoring.')
param logAnalyticsWorkspaceName string

@description('Required. Name of the AKS cluster.')
param aksClusterName string

@description('Required. Name of the Azure Key Vault.')
param keyVaultName string

@description('Required. Name of the Azure Container Registry.')
param acrName string

// ===========================================================================================================================================
//VNET Parameters
//============================================================================================================================================
@description('Required if deployVNet is true. Address space for the virtual network (e.g., ["10.0.0.0/16"]).')
param vnetAddressSpace array

@description('Required if deployVNet is true. Name of the subnet for private endpoints (ACR, Key Vault).')
param azureResourcesSubnetName string 

@description('Required if deployVNet is true. Address prefix for the subnet for private endpoints (e.g., "10.0.1.0/24").')
param azzureResourcesSubnet string

@description('Required if deployVNet is true. Name of the subnet for the AKS system node pool.')  
param aksSubnetName string 

@description('Required if deployVNet is true. Address prefix for the subnet for the AKS system node pool (e.g., "10.0.2.0/24").')
param aksSubnet string

// ===========================================================================================================================================
// Private DNS Zone Parameters
// ===========================================================================================================================================
@description('Optional. Resource ID of a private DNS zone for the private cluster (e.g., privatelink.<region>.azmk8s.io). Use "system" for AKS-managed zone or "none" to disable.')
param privateDnsZoneResourceId string = 'system'

@description('Optional. Resource ID of the private DNS zone for ACR (privatelink.azurecr.io). Leave empty to skip private DNS zone configuration.')
param acrPrivateDnsZoneResourceId string = ''

@description('Optional. Resource ID of the private DNS zone for Key Vault (privatelink.vaultcore.azure.net). Leave empty to skip private DNS zone configuration.')
param keyVaultPrivateDnsZoneResourceId string = ''

// ===========================================================================================================================================
//Log Analytics Workspace Parameters
//============================================================================================================================================
@description('Optional. Name of the Log Analytics Workspace for AKS monitoring. Defaults to "loganalytics-{uniqueString(resourceGroup().id)}".')
param loganalyticsWorkspaceLocation string = location

@description('Optional. SKU for the Log Analytics Workspace. Defaults to PerGB2018.')
@allowed([
  'Free'
  'LACluster'
  'PerGB2018' 
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param logAnalyticsSkuName string = 'PerGB2018'

@description('Optional. Retention period in days for the Log Analytics Workspace. Defaults to 30 days.')
param logAnalyticsRetentionInDays int = 30

// ===========================================================================================================================================
// Azure Key Vault Parameters
// ===========================================================================================================================================  
param keyVaultSku string 
  
// ===========================================================================================================================================
// Azure Container Registry Parameters
// ===========================================================================================================================================
@description('Optional. SKU for the Azure Container Registry. Defaults to Premium for advanced features like private endpoints and geo-replication.')
param acrSku string 

@description('Optional. Zone redundancy for the Azure Container Registry. Defaults to Disabled.')
param acrZoneRedundancy string = 'Disabled' // Enabled or Disabled

@description('Optional. Flag to enable admin user for the Azure Container Registry. Defaults to false for better security.')
param acrAdminUserEnabled bool = false

@description('Optional. Soft delete policy status for the Azure Container Registry. Defaults to Disabled.')
param acrsoftDeletePolicyStatus string = 'Disabled' // Enabled or Disabled

// ===========================================================================================================================================
// AKS Cluster Parameters
// ===========================================================================================================================================
@description('Optional. Preset configuration for the AKS cluster. Defaults to "dev". Presets can be defined in a separate parameters file to apply a set of related parameter values for different environments (e.g., dev, prod).')
@allowed([
  'dev'
  'prod'
])
param ClusterPreset string = 'dev'

@description('Optional. SKU tier for the AKS cluster. Defaults to Standard.')
@allowed([
  'Standard'
  'Free'
])
param aksTier string = 'Standard' // Standard or Free

@description('Optional. Flag to enable private cluster for the AKS cluster. Defaults to true.')
param enablePrivateCluster bool = true

@description('Optional. Kubernetes version for the AKS cluster. Defaults to the latest stable version if not specified.')
param kubernetesVersion string = '' // If empty, the latest stable version will be used

param aksManagedIdentityPrincipalId string = '' // This will be populated with the AKS cluster's system-assigned managed identity principal ID after deployment, and used for role assignments in the modules below
@description('Optional. Flag to enable Azure AD integration for the AKS cluster. Defaults to true.')
param enabledAadIntegration bool = true

@description('Optional. Flag to enable Azure RBAC for the AKS cluster. Defaults to true.')
param enableAzureRBAC bool = true

@description('Optional. Flag to enable Key Vault Secrets Provider for the AKS cluster. Defaults to true.')
param enableKeyVaultSecretsProvider bool = true

@description('Optional. Flag to enable secret rotation for the AKS cluster. Defaults to true.')
param enableSecretRotation bool 

@description('Optional. Network plugin mode for the AKS cluster. Defaults to "overlay" for kubenet (flannel). Set to "transparent" for Azure CNI, which requires BYO VNET with sufficient IP address space for pods and nodes.')
param NetworkPluginMode string = 'overlay' // 'overlay' for kubenet (flannel), 'transparent' for Azure CNI (requires BYO VNET)

@description('Optional. Network plugin for the AKS cluster. Defaults to "azure" for Azure CNI when NetworkPluginMode is "transparent", or "kubenet" for kubenet when NetworkPluginMode is "overlay".')
param NetworkPlugin string = 'azure' // 'azure' for Azure CNI, 'kubenet' for kubenet
//===========================================================================================================================================
// Node Pool Parameters
//===========================================================================================================================================
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
param userPoolMaxCount int = 3

@description('Optional. Maximum number of pods per node. Defaults to 30, which is a common best practice for AKS clusters.')
param maxPodsPerNode int = 30

@description('Optional. Upgrade channel for the AKS cluster. Defaults to "stable". Set to "patch" for more frequent patch updates, "rapid" for the latest features, or "node-image-only" for only node image updates without Kubernetes version changes.')
param upgradechannel string = 'stable' // 'stable', 'patch', 'rapid', or 'node-image-only'

@description('Optional. Flag to enable virtual nodes (ACI) for the AKS cluster. Defaults to false.')
param enableVirtualNodes bool = false

@description('Optional. Operating system type for the AKS cluster nodes. Defaults to "Linux".')
param osType string = 'Linux' // 'Linux' or 'Windows'

@description('Optional. Flag to enable network policy for the AKS cluster. Defaults to "azure" for Azure CNI or "calico" for kubenet.')
param systempoolAvailabilityZones array = [] // Optional. Availability zones for the system node pool (e.g., [1, 2, 3]). If empty, no zone redundancy will be applied.

@description('Optional. Flag to enable network policy for the AKS cluster. Defaults to "azure" for Azure CNI or "calico" for kubenet.')
param userpoolAvailabilityZones array = [] // Optional. Availability zones for the user node pool (e.g., [1, 2, 3]). If empty, no zone redundancy will be applied.  

@description('Optional. Flag to enable network policy for the AKS cluster. Defaults to "azure" for Azure CNI or "calico" for kubenet.')
param enableImageCleaner bool = true

// ===========================================================================================================================================
// Networking Parameters
// ===========================================================================================================================================
  
@description('Optional. Kubernetes service CIDR. Must not overlap with the VNET address space.')
param serviceCidr string = '172.20.30.0/24'

@description('Optional. DNS service IP. Must be within the serviceCidr range.')
param dnsServiceIP string = '172.20.30.10'

@description('Optional. Flag to enable Istio for the AKS cluster. Defaults to false.')
param enableIstio bool = false

@description('Optional. Network policy for the AKS cluster. Defaults to "azure" for Azure CNI or "calico" for kubenet.')
param networkpolicy string = 'azure' // 'azure' for Azure CNI, 'calico' for kubenet
// ===========================================================================================================================================
//AKS Upgrade and Maintenance Parameters
//==========================================================================================================================================
@description('Optional. Upgrade schedule type for the AKS cluster. Defaults to "Weekly". Set to "None" for no automatic upgrades, "Weekly" for upgrades on a specific day of the week, or "Monthly" for upgrades on a specific day of the month.')
@allowed([
  'None'
  'Weekly'
  'Monthly'
])
param aksUpgradeSheduleType string = 'Weekly'

@description('Optional. Day of the week for the AKS cluster upgrade. Required if aksUpgradeSheduleType is "Weekly".')
@allowed([
  'Monday'
  'Tuesday'
  'Wednesday'
  'Thursday'
  'Friday'
  'Saturday'
  'Sunday'
])
param aksUpgradeDayofWeek string = 'Sunday'

@description('Optional. Interval in weeks for the upgrade schedule. Required if aksUpgradeSheduleType is "Weekly".')
param aksUpgradeIntervalWeeks int = 1 

@description('Optional. Day of the month for the AKS cluster upgrade. Required if aksUpgradeSheduleType is "Monthly". Must be between 1 and 28.')
param aksUpgradeIntervalDays int = 1 

@description('Optional. Start time for the AKS cluster upgrade schedule in ISO 8601 format (e.g., "2024-07-01T00:00:00Z").')
param aksUpgradeStartTime string = '2024-07-01T00:00:00Z'

@description('Optional. Duration in hours for the maintenance window during AKS cluster upgrades. Defaults to 3 hours.')
param aksUpgradeDurationInHours int = 4

// ===========================================================================================================================================
// Monitoring Parameters
// ===========================================================================================================================================
@description('Optional. Flag to enable Container Insights monitoring for the AKS cluster. Defaults to true.')
param enablecontainerInsights bool = true

// ===========================================================================================================================================  
//Resource Group
//============================================================================================================================================
module resourceGroupModule 'bicep-avm-modules/avm/res/resources/resource-group/main.bicep' = {
  name: 'resourceGroupDeployment'
  scope: subscription(SubscriptionId)
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}


//===========================================================================
//Virtual Network and Subnets
//===========================================================================
module vnetModule 'bicep-avm-modules/avm/res/network/virtual-network/main.bicep' = if (deployVNet) {
  name: 'vnetDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefixes: vnetAddressSpace
    subnets: [
      {
        name: azureResourcesSubnetName
        addressPrefix: azzureResourcesSubnet
      }
      {
        name: aksSubnetName
        addressPrefix: aksSubnet
      }
    ]
  }
}

//===========================================================================
//Log Analytics Workspace
//===========================================================================
module logAnalyticsWorkspace 'bicep-avm-modules/avm/res/operational-insights/workspace/main.bicep' = if (deployLogAnalyticsWorkspace) {
  name: 'logAnalyticsWorkspaceDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: logAnalyticsWorkspaceName
    location: loganalyticsWorkspaceLocation
    tags: tags
    skuName: logAnalyticsSkuName
    dataRetention: logAnalyticsRetentionInDays
  }
}

// ==========================================================================
// Azure Container Registry 
// ========================================================================== 

module acr 'bicep-avm-modules/avm/res/container-registry/registry/main.bicep' = if (deployAcr) {
  name: 'acrDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: acrName
    location: location
    tags: tags
    acrSku: acrSku 
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: acrZoneRedundancy
    acrAdminUserEnabled: acrAdminUserEnabled
    softDeletePolicyStatus: acrsoftDeletePolicyStatus

    privateEndpoints: deployAcrPrivateEndpoint ? [
      {
        name: '${acrName}-pe'
        service: 'registry'
        subnetResourceId: vnetModule!.outputs.subnetResourceIds[0] // Use the first subnet for private endpoints. Adjust if you have multiple subnets.
        privateDnsZoneGroup: !empty(acrPrivateDnsZoneResourceId) ? {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: acrPrivateDnsZoneResourceId
            }
          ]
        } : null
      }
    ]:[
      ]
  }
}

// ==================================================================
// Azure Key Vault  
// ===================================================================

module keyVault './bicep-avm-modules/avm/res/key-vault/vault/main.bicep' = if (deployKeyVault) {
  name: 'KeyVaultDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: keyVaultName
    location: location
    sku: keyVaultSku
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
       virtualNetworkRules: []
    }
    enableVaultForDeployment:false
    enableVaultForDiskEncryption:false
    enableVaultForTemplateDeployment:false
    privateEndpoints: deployKeyVaultPrivateEndpoint ? [
      {
        name: '${keyVaultName}-pe'
        subnetResourceId: vnetModule!.outputs.subnetResourceIds[0] // Use the first subnet for private endpoints. Adjust if you have multiple subnets.
        service: 'vault'
        privateDnsZoneGroup: !empty(keyVaultPrivateDnsZoneResourceId) ? {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
            }
          ]
        } : null
      }
    ]:[  
    ]
  }
}

// =========================================================================
// AKS Cluster  
// =========================================================================
 module aksModule 'bicep-avm-modules/avm/res/container-service/managed-cluster/main.bicep' = if (deployAksCluster) {
  name: 'aksClusterDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
    vnetModule
    acr
    keyVault
  ]
  params: {
    name: aksClusterName
    location: location
    tags: union(tags, {
      ClusterPreset: ClusterPreset
    })
    managedIdentities: {
      systemAssigned: true
    }
    aadProfile: {
      enableAzureRBAC: enableAzureRBAC
      managed: enabledAadIntegration
    }
    enableOidcIssuerProfile: enabledAadIntegration
    enableRBAC: enableAzureRBAC
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
      privateDNSZone: privateDnsZoneResourceId
    }
    networkPluginMode: NetworkPluginMode
    networkPlugin: NetworkPlugin
    podCidr:'10.244.0.0/16' // Required for kubenet (flannel) network plugin. Ignored for Azure CNI.
    networkPolicy: networkpolicy
    serviceCidr: serviceCidr
    dnsServiceIP: dnsServiceIP
    kubernetesVersion: kubernetesVersion
    skuTier: aksTier
    loadBalancerSku: 'Standard'
    outboundType: 'loadBalancer'
    aciConnectorLinuxEnabled: enableVirtualNodes
    // Addons
   serviceMeshProfile: enableIstio ? {
      mode: 'Istio'
      istio: {
        revisions: [
          'asm-1-20' // Example revision, check AVM docs for latest supported
        ]
      }
    } : null
    // Monitoring
   omsAgentEnabled: enablecontainerInsights
   monitoringWorkspaceResourceId: logAnalyticsWorkspace!.outputs.resourceId
    // Key Vault CSI and Secret Rotation
    enableKeyvaultSecretsProvider: enableKeyVaultSecretsProvider
    enableSecretRotation: enableSecretRotation
    // Node Pools
    primaryAgentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        vmSize: systemPoolVmSize
        vnetSubnetResourceId: vnetModule!.outputs.subnetResourceIds[1] // Use the second subnet for the system node pool. Adjust if you have multiple subnets.
        availabilityZones: systempoolAvailabilityZones
        enableAutoScaling: true
        minCount: systemPoolMinCount
        maxCount: systemPoolMaxCount
        count: systemPoolMinCount
        maxPods: maxPodsPerNode
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        osType: osType
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
    agentPools: [
      {
        name: 'userpool'
        mode: 'User'
        vmSize: userPoolVmSize
        vnetSubnetResourceId:vnetModule!.outputs.subnetResourceIds[1] // Use the second subnet for the user node pool. Adjust if you have multiple subnets.
        availabilityZones: userpoolAvailabilityZones
        enableAutoScaling: true
        minCount: userPoolMinCount
        maxCount: userPoolMaxCount
        count: userPoolMinCount
        maxPods: maxPodsPerNode
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        osType: osType
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        enableNodePublicIP: false
        scaleSetPriority: 'Regular'
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    // Upgrade Channel
    autoUpgradeProfile: {
      upgradeChannel: upgradechannel
    }
   costAnalysisEnabled: true
   enableStorageProfileDiskCSIDriver: true
   maintenanceConfigurations:[
      {
        name: 'aksManagedAutoUpgradeSchedule'
        maintenanceWindow:{
          schedule: aksUpgradeSheduleType == 'Weekly' ? {
            weekly: {
              dayOfWeek:aksUpgradeDayofWeek
              intervalWeeks:aksUpgradeIntervalWeeks
            }
          }:{
            daily:{
              intervalDays:aksUpgradeIntervalDays
            }
          }
          startTime: aksUpgradeStartTime
          durationHours: aksUpgradeDurationInHours  
      }
    }
    {
      name:'aksManagedNodeOSUpgradeSchedule'
      maintenanceWindow:{
        schedule: aksUpgradeSheduleType == 'Weekly' ? {
          weekly: {
            dayOfWeek: aksUpgradeDayofWeek
            intervalWeeks:aksUpgradeIntervalWeeks
          }
        } : {
          daily: {
            intervalDays: aksUpgradeIntervalDays
          }
        }
        startTime: aksUpgradeStartTime
        durationHours: aksUpgradeDurationInHours
      }
    }
   ]
 
    // Security Profile
    securityProfile: {
      imageCleaner: {
        enabled: enableImageCleaner
        intervalHours: 168 // 1 week
      }
    }
     // Maintenance Configurations: Every week on Sunday at 00:00 UTC
    }
}

// ===========================================================================
// Grant AKS managed identity AcrPull on ACR (via module)
// ===========================================================================
// Variable for safe access to AKS system-assigned managed identity principalId
module acrPullRoleAssignment 'modules/acr-pull-role-assignment.bicep' = if (deployAcrRoleAssignment) {
  name: 'acrPullRoleAssignment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  params: {
    acrName: acrName
    principalId: aksManagedIdentityPrincipalId
  }
  dependsOn: [
    acr
  ]
}

// ===========================================================================
// Grant AKS managed identity Key Vault Secrets User on Key Vault (via module)
// ===========================================================================
module keyVaultSecretsRoleAssignment 'modules/keyvault-secrets-role-assignment.bicep' = if (deployKeyVaultRoleAssignment) {
  name: 'keyVaultSecretsRoleAssignment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  params: {
    keyVaultName: keyVaultName
    principalId: aksManagedIdentityPrincipalId
  }
  dependsOn: [
    keyVault
  ]
}

// ========= //
// Outputs    //
// ========= //


@description('The name of the AKS cluster.')
output clusterName string = (deployAksCluster && aksModule!.outputs.name != null) ? aksModule!.outputs.name : ''

@description('The resource ID of the AKS cluster.')
output clusterResourceId string = (deployAksCluster && aksModule!.outputs.resourceId != null) ? aksModule!.outputs.resourceId : ''

@description('The control plane FQDN (private) of the AKS cluster.')
output controlPlaneFQDN string = (deployAksCluster && aksModule!.outputs.controlPlaneFQDN != null) ? aksModule!.outputs.controlPlaneFQDN : ''

@description('The name of the Azure Container Registry.')
output acrName string = (deployAcr && acr!.outputs.name != null) ? acr!.outputs.name : ''

@description('The login server of the Azure Container Registry.')
output acrLoginServer string = (deployAcr && acr!.outputs.loginServer != null) ? acr!.outputs.loginServer : ''

@description('The resource ID of the Azure Container Registry.')
output acrResourceId string = (deployAcr && acr!.outputs.resourceId != null) ? acr!.outputs.resourceId : ''

@description('The name of the Key Vault.')
output keyVaultName string = (deployKeyVault && keyVault!.outputs.name != null) ? keyVault!.outputs.name : ''

@description('The resource ID of the Key Vault.')
output keyVaultResourceId string = (deployKeyVault && keyVault!.outputs.resourceId != null) ? keyVault!.outputs.resourceId : ''

@description('The URI of the Key Vault.')
output keyVaultUri string = (deployKeyVault && keyVault!.outputs.uri != null) ? keyVault!.outputs.uri : ''
