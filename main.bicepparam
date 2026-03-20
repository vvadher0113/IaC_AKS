using 'main.bicep'

// =====================================================
// Parameter values — update these for your environment
// =====================================================

param clusterName = 'aks-private-001'

// Resource ID of your existing subnet for the AKS system node pool
param systemPoolSubnetResourceId = '<your-subnet-resource-id>'
// Example: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-aks/subnets/sn-aks-system'

// (Optional) Separate subnet for the user node pool — defaults to systemPoolSubnetResourceId
// param userPoolSubnetResourceId = '<your-user-pool-subnet-resource-id>'

// Azure Container Registry name (must be globally unique, alphanumeric only)
param acrName = '<your-acr-name>'

// Azure Key Vault name (must be globally unique)
param keyVaultName = '<your-keyvault-name>'

// (Optional) Subnet for ACR & Key Vault private endpoints — defaults to systemPoolSubnetResourceId
// param privateEndpointSubnetResourceId = '<your-pe-subnet-resource-id>'

// (Optional) Private DNS zone resource IDs for ACR and Key Vault private endpoints
// param acrPrivateDnsZoneResourceId = '/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
// param keyVaultPrivateDnsZoneResourceId = '/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'

// (Optional) Kubernetes version — leave empty for latest stable
// param kubernetesVersion = '1.30'

// (Optional) Private DNS Zone — 'system' lets AKS manage it, or provide a resource ID
// param privateDnsZoneResourceId = '/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/privateDnsZones/privatelink.<region>.azmk8s.io'

param tags = {
  environment: 'production'
  managedBy: 'bicep'
}
