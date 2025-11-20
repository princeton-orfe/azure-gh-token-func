#!/bin/bash

set -e

echo "============================================"
echo "  GitHub Token Function - Cleanup"
echo "============================================"
echo ""

# Collect required information
read -p "Function App name to delete: " FUNCTION_APP_NAME
read -p "Resource Group name: " RESOURCE_GROUP

if [[ -z "$FUNCTION_APP_NAME" || -z "$RESOURCE_GROUP" ]]; then
    echo "Error: Function App name and Resource Group are required."
    exit 1
fi

echo ""
echo "--- Checking Azure CLI authentication ---"
if ! az account show > /dev/null 2>&1; then
    echo "Error: Not logged in to Azure CLI. Run 'az login' first."
    exit 1
fi

# Check if function app exists
if ! az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "Error: Function app '$FUNCTION_APP_NAME' not found in resource group '$RESOURCE_GROUP'."
    exit 1
fi

# Get associated resources
echo ""
echo "--- Finding associated resources ---"

# Get storage account from app settings
STORAGE_CONN=$(az functionapp config appsettings list \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?name=='AzureWebJobsStorage' || name=='DEPLOYMENT_STORAGE_CONNECTION_STRING'].value | [0]" -o tsv 2>/dev/null || echo "")

STORAGE_ACCOUNT=""
if [[ -n "$STORAGE_CONN" ]]; then
    STORAGE_ACCOUNT=$(echo "$STORAGE_CONN" | grep -oP 'AccountName=\K[^;]+' || echo "")
fi

# Get Application Insights
APP_INSIGHTS=$(az monitor app-insights component show \
    --app "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "name" -o tsv 2>/dev/null || echo "")

echo ""
echo "--- Resources to delete ---"
echo "Function App:        $FUNCTION_APP_NAME"
if [[ -n "$STORAGE_ACCOUNT" ]]; then
    echo "Storage Account:     $STORAGE_ACCOUNT"
fi
if [[ -n "$APP_INSIGHTS" ]]; then
    echo "Application Insights: $APP_INSIGHTS"
fi

echo ""
echo "WARNING: This will permanently delete the above resources."
read -p "Are you sure you want to proceed? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete function app
echo ""
echo "--- Deleting function app ---"
az functionapp delete --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP"
echo "Function app deleted."

# Delete storage account
if [[ -n "$STORAGE_ACCOUNT" ]]; then
    echo ""
    echo "--- Deleting storage account ---"
    read -p "Delete storage account '$STORAGE_ACCOUNT'? [y/N]: " DELETE_STORAGE
    if [[ "$DELETE_STORAGE" =~ ^[Yy]$ ]]; then
        az storage account delete --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --yes
        echo "Storage account deleted."
    else
        echo "Storage account kept."
    fi
fi

# Delete Application Insights
if [[ -n "$APP_INSIGHTS" ]]; then
    echo ""
    echo "--- Deleting Application Insights ---"
    read -p "Delete Application Insights '$APP_INSIGHTS'? [y/N]: " DELETE_INSIGHTS
    if [[ "$DELETE_INSIGHTS" =~ ^[Yy]$ ]]; then
        az monitor app-insights component delete --app "$APP_INSIGHTS" --resource-group "$RESOURCE_GROUP"
        echo "Application Insights deleted."
    else
        echo "Application Insights kept."
    fi
fi

echo ""
echo "============================================"
echo "  Cleanup Complete"
echo "============================================"
