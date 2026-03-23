using './main.bicep'

param location = 'West US'
param SubscriptionId = ''

param aksManagedIdentityPrincipalId = '' // This should be the principal ID of the AKS cluster's system-assigned managed identity. You can leave it as an empty string if you plan to populate it after deployment.

param tags = {
  environment: 'dev'
  project: 'aks-deployment'
  owner: 'Vijay Vadher'
}

// ===========================================================================================================================================
// Feature Flags
// ===========================================================================================================================================

param deployVNet = false
param deployLogAnalyticsWorkspace = false
param deployKeyVault = false
param deployAcr = false

param deployKeyVaultPrivateEndpoint = false
param deployAcrPrivateEndpoint = false

param deployAksCluster = false

param deployKeyVaultRoleAssignment  = true
param deployAcrRoleAssignment  = true
// ===========================================================================================================================================
// Azure Resource Naming Parameters
// ===========================================================================================================================================
param resourceGroupName = 'vv-aks-rg'
param vnetName = 'vv-aks-vnet'
param logAnalyticsWorkspaceName = 'vv-aks-log'
param aksClusterName = 'vv-aks-cluster'
param keyVaultName = 'vv-aks-kv'
param acrName = 'vvaksacr01'

// ===========================================================================================================================================
// VNET Parameters
// ===========================================================================================================================================
param vnetAddressSpace = [ '10.250.250.0/24']
param azureResourcesSubnetName = 'AzureResourcesSubnet'
param azzureResourcesSubnet = '10.250.250.0/26'
param aksSubnetName = 'AksSubnet'
param aksSubnet = '10.250.250.64/26'

// ===========================================================================================================================================
// Private DNS Zone Parameters
// ===========================================================================================================================================
param privateDnsZoneResourceId = 'system'
param acrPrivateDnsZoneResourceId = '/subscriptions/ca16bf0f-3a7a-42e8-9e31-f7f558d91ad1/resourceGroups/vv-aks-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
param keyVaultPrivateDnsZoneResourceId = '/subscriptions/ca16bf0f-3a7a-42e8-9e31-f7f558d91ad1/resourceGroups/vv-aks-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'

// ===========================================================================================================================================
// Log Analytics Workspace Parameters
// ===========================================================================================================================================
param loganalyticsWorkspaceLocation = 'West US'
param logAnalyticsSkuName = 'PerGB2018'
param logAnalyticsRetentionInDays = 30

// ===========================================================================================================================================
// Azure Key Vault Parameters
// ===========================================================================================================================================
param keyVaultSku = 'standard'

// ===========================================================================================================================================
// Azure Container Registry Parameters
// ===========================================================================================================================================
param acrSku = 'Premium'
param acrZoneRedundancy = 'Disabled'
param acrAdminUserEnabled = false
param acrsoftDeletePolicyStatus = 'disabled'

// ===========================================================================================================================================
// AKS Cluster Parameters
// ===========================================================================================================================================
param ClusterPreset = 'dev'
param aksTier = 'Standard'
param enablePrivateCluster = true
param kubernetesVersion = '1.35'
param enabledAadIntegration = true
param enableAzureRBAC = true
param enableKeyVaultSecretsProvider = true
param enableSecretRotation = true
param NetworkPluginMode = 'overlay'
param NetworkPlugin = 'azure'
param networkpolicy = 'azure'

// ===========================================================================================================================================
// Node Pool Parameters
// ===========================================================================================================================================
param systemPoolVmSize = 'Standard_DS2_v2'
param userPoolVmSize = 'Standard_DS2_v2'
param systemPoolMinCount = 1
param systemPoolMaxCount = 3
param userPoolMinCount = 1
param userPoolMaxCount = 3
param maxPodsPerNode = 30
param upgradechannel = 'stable'
param enableVirtualNodes = false
param osType = 'Linux'
param systempoolAvailabilityZones = []
param userpoolAvailabilityZones = []
param enableImageCleaner = true

// ===========================================================================================================================================
// AKS Cluster Auto-Upgrade Parameters  
// ===========================================================================================================================================
param aksUpgradeSheduleType = 'Weekly' // Options: 'Weekly', 'Daily'
param aksUpgradeDayofWeek = 'Sunday' // Required if aksUpgradeSheduleType is 'Weekly'. Options: 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'.
param aksUpgradeIntervalWeeks = 1 // Required if aksUpgradeSheduleType is 'Weekly'. Interval in weeks for the AKS cluster upgrade.
param aksUpgradeIntervalDays = 1 // Required if aksUpgradeSheduleType is 'Daily'. Interval in days for the AKS cluster upgrade.
param aksUpgradeStartTime = '00:00' // Start time for the AKS cluster upgrade.
param aksUpgradeDurationInHours = 4 // Duration in hours for the AKS cluster upgrade.
// ===========================================================================================================================================
// Networking Parameters
// ===========================================================================================================================================
param serviceCidr = '172.20.30.0/24'
param dnsServiceIP = '172.20.30.10'
param enableIstio = false

// ===========================================================================================================================================
// Monitoring Parameters
// ===========================================================================================================================================
param enablecontainerInsights = true
