# Azure DevOps Pipeline Security & Deployment Guide

## Overview

This pipeline implements secure Bicep template deployments using:

- **Workload Identity Federation** (OpenID Connect) for authentication—no long-lived secrets stored
- **Separate service connections** per environment with least privilege RBAC
- **Validation & What-If analysis** before deployments
- **Manual approval gates** for production releases

## Architecture

### Pipeline Stages

1. **Validate**: Lints and validates all Bicep files
2. **Dev**: Automated deployment with What-If preview
3. **Test**: Automated deployment after Dev succeeds
4. **Prod**: Manual approval required before deployment

### Service Connections Setup

Three separate service connections for dev/test/prod with federated identity.

#### Prerequisites

- Azure subscription(s) with appropriate resource groups created:
  - `mre-dev-rg` (Development)
  - `mre-test-rg` (Test)
  - `mre-prod-rg` (Production)
- Azure DevOps organization and project
- Rights to create service connections and manage Azure role assignments

#### Creating Service Connections with Federated Identity

##### Step 1: Create Azure AD Applications

For each environment, create an Azure AD app registration:

```bash
# For dev environment
az ad app create --display-name "devops-pipeline-dev"
DEV_APP_ID=$(az ad app list --display-name "devops-pipeline-dev" --query "[0].appId" -o tsv)
DEV_APP_OBJECT_ID=$(az ad app show --id $DEV_APP_ID --query id -o tsv)

# Repeat for test and prod
az ad app create --display-name "devops-pipeline-test"
TEST_APP_ID=$(az ad app list --display-name "devops-pipeline-test" --query "[0].appId" -o tsv)

az ad app create --display-name "devops-pipeline-prod"
PROD_APP_ID=$(az ad app list --display-name "devops-pipeline-prod" --query "[0].appId" -o tsv)
```

##### Step 2: Create Service Principals

```bash
# Create service principal for dev
DEV_SP_ID=$(az ad sp create --id $DEV_APP_ID --query id -o tsv)

# Create service principal for test
TEST_SP_ID=$(az ad sp create --id $TEST_APP_ID --query id -o tsv)

# Create service principal for prod
PROD_SP_ID=$(az ad sp create --id $PROD_APP_ID --query id -o tsv)
```

##### Step 3: Configure Federated Credentials

For each environment, create a federated credential that ties the Azure AD app to your Azure DevOps organization and project:

```bash
# For dev environment
az ad app federated-credential create \
  --id $DEV_APP_ID \
  --parameters '{
    "name": "devops-dev",
    "issuer": "https://vstoken.dev.azure.com/<organization-id>",
    "subject": "sc://danwrightlondon/munichre-tech-assessment/dev-conn",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Replace <organization-id>, <organization>, and <project> with your values
# For test
az ad app federated-credential create \
  --id $TEST_APP_ID \
  --parameters '{
    "name": "devops-test",
    "issuer": "https://vstoken.dev.azure.com/<organization-id>",
    "subject": "sc://danwrightlondon/munichre-tech-assessment/test-conn",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For prod
az ad app federated-credential create \
  --id $PROD_APP_ID \
  --parameters '{
    "name": "devops-prod",
    "issuer": "https://vstoken.dev.azure.com/<organization-id>",
    "subject": "sc://danwrightlondon/munichre-tech-assessment/prod-conn",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

##### Step 4: Assign Least Privilege RBAC

Assign each service principal to its respective resource group with minimal permissions:

```bash
# Dev: Contributor scope limited to dev resource group
az role assignment create \
  --assignee $DEV_SP_ID \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/munich-kv-dev"

# Test: Contributor scope limited to test resource group
az role assignment create \
  --assignee $TEST_SP_ID \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/munich-kv-test"

# Prod: Contributor scope limited to prod resource group
# (Consider Reader role + custom role for production with restricted operations)
az role assignment create \
  --assignee $PROD_SP_ID \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/munich-kv-prod"
```

##### Step 5: Create Service Connections in Azure DevOps

In Azure DevOps (Project Settings → Service Connections):

1. **Create Service Connection** → **Azure Resource Manager**
2. **Authentication Method**: Workload Identity Federation (OpenID Connect)
3. Fill in:
   - **Subscription ID**
   - **Subscription Name**
   - **Service Principal Client ID** (from your Azure AD app)
   - **Tenant ID**
   - **Service Connection Name**: `dev-conn`, `test-conn`, `prod-conn`

## Security Best Practices Implemented

### 1. No Long-Lived Secrets

- Uses **OpenID Connect (OIDC)** and federated credentials
- Token is short-lived and issued on-demand at runtime
- No stored secrets in Azure DevOps or Key Vault

### 2. Least Privilege RBAC

- Each service connection has **Contributor role scoped to its resource group only**
- Cannot access other resource groups or subscriptions
- For production, consider using a custom role with restricted operations (e.g., read-only or specific resource types)

### 3. Validation & Preview

- **Bicep Lint**: Validates syntax and best practices
- **What-If Analysis**: Shows resource changes before deployment
- **Parameter Validation**: Ensures bicepparam files are correct

### 4. Approval Gates

- **Dev**: Automatic deployment
- **Test**: Automatic deployment (after Dev succeeds)
- **Prod**: **Manual approval required** before deployment
- Approvers can review What-If output to understand impact

### 5. Resource Group Isolation

- Each environment has its own resource group
- Deployments are scoped to resource group level
- Cannot accidentally deploy to wrong environment

## Environment Variables & Variable Groups

Create three Azure DevOps variable groups:

### dev-deployment-vars

```
# Optional: deployment-specific variables
NOTIFICATION_EMAIL=dev-team@example.com
```

### test-deployment-vars

```
# Optional: deployment-specific variables
NOTIFICATION_EMAIL=test-team@example.com
```

### prod-deployment-vars

```
# Optional: deployment-specific variables
NOTIFICATION_EMAIL=admin@example.com
DEPLOYMENT_APPROVAL_TIMEOUT=24 # hours
```

## Deployment Flow

### 1. Validation Stage

```
Lint main.bicep → Lint modules → Validate parameters
```

### 2. Dev Deployment

```
What-If (shows changes) → [Automatic] → Deploy
```

### 3. Test Deployment (runs after Dev succeeds)

```
What-If (shows changes) → [Automatic] → Deploy
```

### 4. Prod Deployment (runs after Test succeeds)

```
What-If (shows changes) → [Manual Approval] → Deploy
```

## Monitoring & Troubleshooting

### View Pipeline Logs

In Azure DevOps, view stage/job logs to see:

- Bicep lint output
- What-If changes
- Deployment status and errors

### Common Issues & Solutions

| Issue                      | Cause                               | Solution                                                            |
| -------------------------- | ----------------------------------- | ------------------------------------------------------------------- |
| "Insufficient privileges"  | Service principal lacks permissions | Verify role assignment scope                                        |
| "Invalid token"            | OIDC configuration incorrect        | Verify federated credential subject matches service connection name |
| "Resource group not found" | Wrong resource group name           | Update resource group name in stage variables                       |
| "Bicep validation failed"  | Template syntax error               | Review lint output and fix template                                 |

### Rollback Procedure

For failed deployments:

```bash
# Get deployment details
az deployment group show \
  --name "bicep-deployment-<build-id>" \
  --resource-group <rg-name> \
  --query properties.provisioningState

# Option 1: Deploy previous working version
git checkout <previous-commit>
# Run pipeline

# Option 2: Delete failed resources manually
az resource delete --id /subscriptions/.../resourceGroups/.../providers/.../resources/<name>
```

## Production Hardening Recommendations

1. **Custom RBAC Role for Prod**

   ```json
   {
     "Name": "Bicep Deployer - Production",
     "IsCustom": true,
     "Description": "Minimal permissions for Bicep deployments",
     "Actions": [
       "Microsoft.Resources/deployments/*",
       "Microsoft.KeyVault/vaults/*",
       "Microsoft.Authorization/*/read"
     ],
     "NotActions": [
       "Microsoft.Resources/deployments/delete",
       "Microsoft.KeyVault/vaults/delete"
     ],
     "AssignableScopes": ["/subscriptions/<id>/resourceGroups/mre-prod-rg"]
   }
   ```

2. **Multi-Level Approvals**
   - Add multiple approvers for production
   - Require specific team leads or security review

3. **Audit Logging**
   - Enable Azure Resource Manager audit logs
   - Monitor all deployment activities
   - Alert on unexpected changes

4. **Network Security**
   - Restrict Key Vault access via network ACLs (already configured in Bicep)
   - Consider self-hosted agents for private deployments

5. **Secrets in Key Vault**
   - Any sensitive data should be stored in Azure Key Vault
   - Reference via Bicep parameters or Key Vault references
   - Service principal must have "Key Vault Secrets User" role

## Maintenance

### Regular Checks

- Review service connection permissions quarterly
- Update Bicep CLI version regularly (`az bicep upgrade`)
- Audit federated credentials expiration (they don't expire, but verify configuration)
- Review approval gate logs and access patterns

### Updating Service Connections

To update a service connection's permissions:

```bash
# Update role assignment (e.g., if adding responsibilities)
az role assignment create \
  --assignee $DEV_SP_ID \
  --role "<new-role-name>" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<rg-name>"
```

## References

- [Azure DevOps Workload Identity Federation](https://docs.microsoft.com/en-us/azure/devops/pipelines/release/connect-to-azure?view=azure-devops#workload-identity-federation)
- [OpenID Connect in Azure](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure RBAC Best Practices](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)
