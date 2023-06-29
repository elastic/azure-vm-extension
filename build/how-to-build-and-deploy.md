# How to build and deploy

This guide shows you how to take the sources on your local machine and build a VM extension version to deploy on Azure.

Requisites:

- PowerShell (I used PowerShell 7.3.5 on macOS)
- Azure CLI (I used version 2.48.1)

## Placeholders

In this guide, you will find several placeholders. 

The value for the following placeholders is private, and you should find them in internal documents:

- [TENANT ID]
- [SUBSCRIPTION ID]
- [PUBLISHER NAME]
- [PUBLISHER TYPE]
- [RESOURCE GROUP]
- [STORAGE ACCOUNT]
- [IS INTERNAL EXTENSION]

The value of these placeholders is determined while going through the steps:

- [EXTENSION VERSION]
- [MEDIA LINK]


## Deploy target: test vs. production

You can deploy the VM extension as a test or production version.

Test versions are available on the internal subscription only. The production version is available to all users.

Test and production have different publisher names and types, resource groups, storage accounts, and "is internal extension" values.


## PowerShell Setup

Set up your PowerShell to use the tenant and subscription that host your VM extension:

```powershell
Connect-AzAccount -TenantId [TENANT ID] -Subscription [SUBSCRIPTION ID]
```

You can double-check the setup is correct by listing previous versions of the VM extension:

```powershell

# linux
get-AzVMExtensionImage -Location "East US" -PublisherName "[PUBLISHER NAME]" -Type "[PUBLISHER TYPE].linux"  

# windows
get-AzVMExtensionImage -Location "East US" -PublisherName "[PUBLISHER NAME]" -Type "[PUBLISHER TYPE].windows"
```


## Build the zip file

The VM extension is packaged in a zip file. There's a PowerShell script that can do this for you:

```shell
# Create the expected deploy folder.
mkdir build/deploy 

# Build the actual zip file.
pwsh build/zip.ps1 
```

This creates two zip file at `build`:

```shell
$ build/deploy
├── linux.zip
└── windows.zip
```

Rename your zip file with a version number to keep track during teh testing phase:

```shell
# Version '1.3.0.0' for Windows, to deploy as a test version.
mv build/deploy/windows.zip build/deploy/windows-test-1300.zip

# Version '1.3.0.0' for Windows, to deploy as a production version.
mv build/deploy/windows.zip build/deploy/windows-1300.zip
```

As a naming convention, you can use `test` in the file name for the version you plan to deploy as a test version only.


## Upload the zip file to the storage account

The deployment process requires the zip file to be available on a storage account container.

Open the **Azure Portal** and:

1. Open **Storage accounts**.
2. Search for a **storage account** named [STORAGE ACCOUNT] and select it, depending on where you plan to deploy.
3. Select **Data storage > Containers**
4. Select the **blob** for the target platform, `linux` or `windows`.
5. Select **Upload** and follow the instructions to upload the zip file.

## Generate the Medialink

Once the zip file is in the blob, we must create a media link to reference it in the deploy template.

From the blob you just uploaded, do the following:

1. Select the zip file you just uploaded.
2. Click on **Generate SAS**.
3. Set an **Expiry date** a couple of weeks in the future.
4. Click on **Generate SAS token and URL**.
5. Copy the **Blob SAS URL** in the clipboard.

Save this **Blob SAS URL** somewhere safe; we'll use it in the next step as [MEDIA LINK].


## Update the deploy template

Update the template file with the appropriate [PUBLISHER NAME], [PUBLISHER TYPE], and [IS INTERNAL EXTENSION] for the deployment target (test or production). 

Replace [EXTENSION VERSION] with the extension version.

Replace [MEDIA LINK] with the value of **Blob SAS URL** you saved during the previous step.

### Templates

#### Linux

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Location for all resources."
            }
        }
    },
    "variables": {
        "publisherName": "[PUBLISHER NAME]",
        "typeName": "[PUBLISHER TYPE].linux",
        "version": "[EXTENSION VERSION]",
        "mediaLink": "[MEDIA LINK]"
    },
    "resources": [
        {
            "type": "Microsoft.Compute/sharedVMExtensions",
            "name": "[concat(variables('publisherName'), '.', variables('typeName'))]",
            "apiVersion": "2019-12-01",
            "location": "[parameters('location')]",
            "properties": {
                "identifier": {
                    "publisher": "[variables('publisherName')]",
                    "type": "[variables('typeName')]"
                },
                "label": "Elastic Agent",
                "description": "Elastic Agent",
                "companyName": "Elastic",
                "privacyUri": "https://www.elastic.co/legal/privacy-statement"
            }
        },
        {
            "type": "Microsoft.Compute/sharedVMExtensions/versions",
            "name": "[concat(variables('publisherName'), '.', variables('typeName'), '/', variables('version'))]",
            "apiVersion": "2019-12-01",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[concat('Microsoft.Compute/sharedVMExtensions/', variables('publisherName'), '.', variables('typeName'))]"
            ],
            "properties": {
                "regions": [
                    "east us"
                ],
                "computeRole": "IaaS",
                "supportedOS": "Linux",
                "isInternalExtension": [IS INTERNAL EXTENSION],
                "safeDeploymentPolicy": "Minimal",
                "mediaLink": "[variables('mediaLink')]"
            }
        }
    ]
}
```

#### Windows

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string",
            "defaultValue": "[resourceGroup().location]",
            "metadata": {
                "description": "Location for all resources."
            }
        }
    },
    "variables": {
        "publisherName": "[PUBLISHER NAME]",
        "typeName": "[PUBLISHER TYPE].windows",
        "version": "[EXTENSION VERSION]",
        "mediaLink": "[MEDIA LINK]"
    },
    "resources": [
        {
            "type": "Microsoft.Compute/sharedVMExtensions",
            "name": "[concat(variables('publisherName'), '.', variables('typeName'))]",
            "apiVersion": "2019-12-01",
            "location": "[parameters('location')]",
            "properties": {
                "identifier": {
                    "publisher": "[variables('publisherName')]",
                    "type": "[variables('typeName')]"
                },
                "label": "Elastic Agent",
                "description": "Elastic Agent",
                "companyName": "Elastic",
                "privacyUri": "https://www.elastic.co/legal/privacy-statement"
            }
        },
        {
            "type": "Microsoft.Compute/sharedVMExtensions/versions",
            "name": "[concat(variables('publisherName'), '.', variables('typeName'), '/', variables('version'))]",
            "apiVersion": "2019-12-01",
            "location": "[parameters('location')]",
            "dependsOn": [
                "[concat('Microsoft.Compute/sharedVMExtensions/', variables('publisherName'), '.', variables('typeName'))]"
            ],
            "properties": {
                "regions": [
                    "east us"
                ],
                "computeRole": "IaaS",
                "supportedOS": "Windows",
                "isInternalExtension": [IS INTERNAL EXTENSION],
                "safeDeploymentPolicy": "Minimal",
                "mediaLink": "[variables('mediaLink')]"
            }
        }
    ]
```


## Deploy the new version in Azure

Now we are ready to deploy the new version in Azure using the template:

```powershell
# linux
New-AzResourceGroupDeployment -ResourceGroupName [RESOURCE GROUP] -TemplateFile ./deploy.linux.json -Verbose  

# windows
New-AzResourceGroupDeployment -ResourceGroupName [RESOURCE GROUP] -TemplateFile ./deploy.windows.json -Verbose  
```


## Check if the new version is available

This is the same command we used before; this time we'll use it to double-check that the new version is available:

```powershell
# linux
get-AzVMExtensionImage -Location "East US" -PublisherName "[PUBLISHER NAME]" -Type "[PUBLISHER TYPE].linux"  

# windows
get-AzVMExtensionImage -Location "East US" -PublisherName "[PUBLISHER NAME]" -Type "[PUBLISHER TYPE].windows" 
```

## Install the extension on a VM

If you deploy the test version, the [RESOURCE GROUP] and [VM NAME] must be on the same [SUBSCRIPTION ID] you deployed the extension into. 

```shell
# Linux
az vm extension set -n "[PUBLISHER TYPE].linux" --publisher "[PUBLISHER NAME]" --version "[EXTENSION VERSION]" --vm-name "[VM NAME]" --resource-group "[RESOURCE GROUP]" --settings "{\"username\":\"[USERNAME]\",\"cloudId\":\"[CLOUD ID]\"}" --protected-settings "{\"password\":\"[PASSWORD]\"}" 

# Windows
az vm extension set -n "[PUBLISHER TYPE].windows" --publisher "[PUBLISHER NAME]" --version "[EXTENSION VERSION]" --vm-name "[VM NAME]" --resource-group "[RESOURCE GROUP]" --settings "{\"username\":\"[USERNAME]\",\"cloudId\":\"[CLOUD ID]\"}" --protected-settings "{\"password\":\"[PASSWORD]\"}" 
```
