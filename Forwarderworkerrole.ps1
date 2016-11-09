Param ( 
    [Parameter(Mandatory=$True)]
    [object]$WebhookData
) 
           
$WebhookBody    =   $WebhookData.RequestBody
$Params = ConvertFrom-Json -InputObject $WebhookBody
Write-Output "Json Data received is $WebhookBody"
  Write-Output "$Params.parameters.Subscriptionid"  
$subscriptionID = $Params.parameters.Subscriptionid   
$subscriptionName = $Params.parameters.Subscriptionname
$templatesubsid = $subscriptionName

$deploymentLocation = $Params.parameters.DeploymentResourceGroupLocation
Write-Output "Deployment location is $deploymentLocation"
     
$AutomationCredentialAssetName = $Params.parameters.AutomationCredentialAssetName
    
if($subscriptionName)
{
	Write-output "Subscription name is $subscriptionName"
} 
else
{
	Write-Output "Please Pass Valid Subscription Name"
	exit
}
  
if($subscriptionID)
{
	Write-output "Subscription Id is $subscriptionID"
} 
else
{
	Write-Output "Please Pass Valid Subscription ID"
	exit
}

try
{ 
	Write-Output "Automation credential is $AutomationCredentialAssetName"
	$cred = Get-AutomationPSCredential -Name $AutomationCredentialAssetName 
    
	Add-AzureRmAccount -Credential $cred -SubscriptionId $subscriptionID  
	Set-AzureRmContext -SubscriptionId $subscriptionID
 
	Write-Output "Login Successful"
}
 catch
 {
	Write-Output "Please Pass Valid AutomationPSCredential"
	exit
 }
 
$ConfigurationBlobName = Get-AutomationVariable -Name "fwdConfigurationBlobName"
$PackageBlobName = Get-AutomationVariable -Name "fwdPackageBlobName"
# $StorageAccountName = Get-AutomationVariable -Name "fwdpkgstorageaccount"
# $StorageContainerName = Get-AutomationVariable -Name "fwdpkgstoragecontaineraccount"
$StorageAccountName = Get-AutomationVariable -Name "templatestorageaccount"
$StorageContainerName = Get-AutomationVariable -Name "templatecontainer"
 
$slot = $Params.parameters.fwddeploymentslot #staging or production
$timeStampFormat = "g"
  
$storageAccountType = Get-AutomationVariable -Name "fwdstorageaccounttype"
$Remoteusername = Get-AutomationVariable -Name "fwdremoteusername"
$Remoteuserpassword=Get-AutomationVariable -Name "fwdremoteuserpwd"

$primaryStorageAccountName1 = $Params.parameters.fwdprimaryaccountname1
$primaryLocation = Get-AutomationVariable -Name "primarylocation"

$primarycloudService = $Params.parameters.fwdprimarycloudService
$deploymentLabelPrimary = "$primarycloudService - $(Get-Date -f $timeStampFormat)"

$ResourceGroupName = Get-AutomationVariable -Name "fwdresourcegroupname"
$ResourceGroupLocation = $deploymentLocation
$verbosePreference = "Continue"

Write-Output "Getting Azure subscription name $subscriptionName and id $subscriptionID"
Get-AzureSubscription -SubscriptionName $subscriptionName
Write-Output "Finished getting Azure subscription"

Add-AzureAccount -Credential $cred

# Select Azure subscription
Write-output "Selecting Azure Subscription"
Select-AzureSubscription -SubscriptionId $subscriptionID
Write-Output "Selected Azure Subscription $subscriptionName"

function Publish()
{
    CreateStorageAccount1
    CreateCloudService
      
	Write-Output "Selecting package location $packageLocation."
	Write-Output "$(Get-Date -f $timeStampFormat) - Publising Azure Deployment..."
	
	$deployment = Get-AzureDeployment -ServiceName $primarycloudService -Slot $slot -ErrorVariable a -ErrorAction silentlycontinue 

	if ($a[0] -ne $null) {
		Write-Output "$(Get-Date -f $timeStampFormat) - No deployment is detected. Creating a new deployment. "
	}

	if ($deployment.Name -ne $null) 
	{
		Write-Output "$(Get-Date -f $timeStampFormat) - Deployment exists in $primarycloudService.  Upgrading deployment."
		UpgradeDeployment
	} 
	else 
	{
		CreateNewDeployment
		Write-Output "Completed Deployment Successfully."
		$securePassword2 = ConvertTo-SecureString $Remoteuserpassword -AsPlainText -Force
		$expiry = $(Get-Date).AddDays(10)
		$credential2 = New-Object System.Management.Automation.PSCredential $Remoteusername,$securepassword2
     
		Set-AzureServiceRemoteDesktopExtension -ServiceName $primarycloudService -Credential $credential2 -Expiration $expiry
	}

    Get-AzureServiceRemoteDesktopExtension -ServiceName $primarycloudService
}

function CreateStorageAccount1()
{
  if (!(Test-AzureName -Storage $primaryStorageAccountName1))
  {  
    Write-output "Creating Storage Account $primaryStorageAccountName1"
    New-AzureStorageAccount -StorageAccountName $primaryStorageAccountName1 -Type $storageAccountType -Location $deploymentLocation
  }
else
  {
     Write-output "Storage Account $primaryStorageAccountName1 already exists."
  }
    $strkey = (Get-AzureStorageKey -StorageAccountName $primaryStorageAccountName1).Primary
    $strCtxt =  New-AzureStorageContext -StorageAccountName $primaryStorageAccountName1 -StorageAccountKey $strkey
    Get-AzureStorageAccount -StorageAccountName $primaryStorageAccountName1
   
   Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $primaryStorageAccountName1
}

function CreateCloudService()
{
	Write-Output "Selecting Cloud Service.."

	if (!(Test-AzureName -Service $primarycloudService))
	{  
		Write-Output "Creating Cloud Service $primarycloudService"
		New-AzureService -ServiceName $primarycloudService -Location $deploymentLocation
	}
	else
	{
		Write-Output "Cloud Service $primarycloudService already exists. So retrieving it"
		Get-AzureService -ServiceName $primarycloudService
	}
}

function CreateNewDeployment()
{
	$subName = $templatesubsid
	Write-Output "Selecting Azure Subscription $subName"
	Get-AzureSubscription -SubscriptionName  $subName
	Write-Output "Selected Azure Subscription $subName"
 
  #Write-Output "Getting storage account..."
    #$StorageAccount = (Get-AzureStorageAccount -StorageAccountName $StorageAccountName).Label
    
    #Write-Output ('Setting the Azure Subscription and Storage Accounts')
    #Set-AzureSubscription  -SubscriptionName $templatesubsid -CurrentStorageAccount $StorageAccount
    
    try
    {
        $Conn = Get-AutomationConnection -Name AzureRunBookDevConnection
        Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint 
        $templateSubscriptionid = Get-AutomationVariable -Name "templateSubscriptionid"
        Set-AzureRmContext -SubscriptionId $templateSubscriptionid
        $Container = Get-AutomationVariable -Name "templatecontainer"  
        $templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
        $StorageAccount  = Get-AutomationVariable -Name "templatestorageaccount"
        $StorageAccountKey=(Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccount -ResourceGroupName $templateresourcegroupname).Value[0]
        $StorageContext = New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey
        
        $TempFileLocation = "C:\$ConfigurationBlobName"
        $BlobFileLocation = "C:\$PackageBlobName"
     
        Write-Output ('CreateNewDeployment: Downloading Service Configurations from Azure Storage')
    
        Get-AzureStorageBlobContent `
            -Container $StorageContainerName `
            -Blob $ConfigurationBlobName `
            -Destination $TempFileLocation `
            -Context (New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey) `
            -Force
        
        Get-AzureStorageBlobContent `
            -Container $StorageContainerName `
            -Blob  $PackageBlobName `
            -Destination $BlobFileLocation `
            -Context (New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey) `
            -Force
    }
    catch
    {
        Write-Output ('Failed getting storage account')
        Write-Output ($_.Exception.Message)
        exit
    }
 
    Write-Output('Downloaded configuration file to: '+ $TempFileLocation)
    Write-Output('Downloaded package file to: '+ $BlobFileLocation)
    Write-Output('Getting Package Url from Azure Storage: '+ $PackageBlobName)
         
    Write-Output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure Subscription $subscriptionName"
    
    Write-Output "Getting Azure subscription $subscriptionName"
    Get-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Finishsed getting Azure subscription $subscriptionName"

    #Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName "runbooktemplates"
            
    New-AzureDeployment `
        -Package $BlobFileLocation `
        -Configuration $TempFileLocation `
        -Slot Production `
        -Label $deploymentLabelPrimary `
        -ServiceName  $primarycloudService `
        -Verbose                
}

function UpgradeDeployment()
{
    Write-Output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $templatesubsid
    Write-Output "Selected Azure Subscription $templatesubsid"
  
    $StorageContext = SetStorageContext
    
    $Conn = Get-AutomationConnection -Name AzureRunBookDevConnection
    Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint 
    $templateSubscriptionid = Get-AutomationVariable -Name "templateSubscriptionid"
    Set-AzureRmContext -SubscriptionId $templateSubscriptionid
    $Container = Get-AutomationVariable -Name "templatecontainer"  
    $templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
    $StorageAccount  = Get-AutomationVariable -Name "templatestorageaccount"
    $StorageAccountKey=(Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccount -ResourceGroupName $templateresourcegroupname).Key1
    #$StorageContext = New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey
 
    $TempFileLocation = "C:\$ConfigurationBlobName"
    $BlobFileLocation = "C:\$PackageBlobName"
    Write-Output ('UpgradeDeployment: Downloading Service Configurations from Azure Storage')
 
    Get-AzureStorageBlobContent `
        -Container $StorageContainerName `
        -Blob  $ConfigurationBlobName `
        -Destination $TempFileLocation `
        -Context (New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey) `
        -Force
        
    Get-AzureStorageBlobContent `
        -Container $StorageContainerName `
        -Blob  $PackageBlobName `
        -Destination $BlobFileLocation `
        -Context (New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey) `
        -Force
 
    Write-Output('Downloaded Configuration File: '+ $TempFileLocation)
    Write-Output('Downloaded Configuration File: '+ $BlobFileLocation)
    Write-Output('Getting Package Url from Azure Storage: '+ $PackageBlobName)

	# Get Azure Subscription
    Write-Output "Getting Azure subscription $subscriptionName"
    Get-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure subscription $subscriptionName"

    # Select Azure subscription
    Write-output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure Subscription $subscriptionName"
 
    #Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName "runbooktemplates"

    Write-Output('Attempting to Update an Existing Deployment')
        Set-AzureDeployment `
            -Package $BlobFileLocation `
            -Configuration $TempFileLocation `
            -Slot Production `
            -Mode Simultaneous `
            -Label $deploymentLabelPrimary `
            -ServiceName  $primarycloudService `
            -Upgrade `
            -Force `
            -Verbose
                
    Write-Output('Attempting to Update an Existing Deployment')
}

function SetStorageContext()
{
    $Conn = Get-AutomationConnection -Name AzureRunBookDevConnection
    Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint 
    $templateSubscriptionid = Get-AutomationVariable -Name "templateSubscriptionid"
    Set-AzureRmContext -SubscriptionId $templateSubscriptionid
    $Container = Get-AutomationVariable -Name "templatecontainer"  
    $templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
    $StorageAccount  = Get-AutomationVariable -Name "templatestorageaccount"
    $StorageAccountKey=(Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccount -ResourceGroupName $templateresourcegroupname).Value[0]
    $StorageContext = New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey
    
    $StorageContext
}

try
{
    Publish
}
catch
{
    throw
    Break
}