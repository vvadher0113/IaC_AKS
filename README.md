## AKS Production Deployment: Two-Step Process for Role Assignments

This project uses a two-step deployment process to ensure AKS managed identity role assignments (ACR Pull and Key Vault Secrets User) are applied correctly.

### Step 1: Deploy Core Infrastructure

Deploy the main infrastructure (AKS, ACR, Key Vault, etc.):

```sh
az deployment sub create \
  --location <location> \
  --template-file main.bicep \
  --parameters @main.bicepparam
```

After deployment, capture the following outputs (from the deployment output or Azure Portal):
- `aksModule.outputs.systemAssignedMIPrincipalId` (AKS managed identity principalId)
- `keyVaultName` (Key Vault name)
- `acrName` (ACR name)

### Step 2: Assign Roles for ACR Pull and Key Vault Secrets

Deploy the role assignment modules using the outputs from Step 1:

```sh
# Assign AcrPull role to AKS managed identity
az deployment group create \
  --resource-group <resource-group> \
  --template-file modules/acr-pull-role-assignment.bicep \
  --parameters acrName=<acrName> principalId=<aksPrincipalId>

# Assign Key Vault Secrets User role to AKS managed identity
az deployment group create \
  --resource-group <resource-group> \
  --template-file modules/keyvault-secrets-role-assignment.bicep \
  --parameters keyVaultName=<keyVaultName> principalId=<aksPrincipalId>
```

Replace `<resource-group>`, `<acrName>`, `<keyVaultName>`, and `<aksPrincipalId>` with the actual values from Step 1.

### How to Get the AKS Managed Identity Principal ID

After your AKS cluster is created, you can retrieve the system-assigned managed identity principalId using the Azure CLI:

```sh
az aks show \
  --resource-group <resource-group> \
  --name <aksClusterName> \
  --query identity.principalId \
  --output tsv
```

Replace `<resource-group>` and `<aksClusterName>` with your actual values. Use the resulting principalId for the role assignment step.

---
**Note:** This two-step process is required because the AKS managed identity principalId is not available until after the AKS resource is created.