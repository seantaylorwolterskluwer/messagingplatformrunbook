Param ( 
	
        [Parameter(Mandatory=$True)]
        [object]$WebhookData
	
    ) 
	
           
$WebhookBody    =   $WebhookData.RequestBody
$Params = ConvertFrom-Json -InputObject $WebhookBody
 

$subscriptionID = $Params.parameters.Subscriptionid.value   
$subscriptionName = $Params.parameters.Subscriptionname.value

# commented out
# $templatesubsid = Get-AutomationVariable -Name "templatesubsid" 
$templatesubsid = $subscriptionName
     
 $AutomationCredentialAssetName = $Params.parameters.AutomationCredentialAssetName.value
    
    if($subscriptionName)
	{
		Write-output "Subscription name is $subscriptionName"
	} else{
		Write-Output "Please Pass Valid Subscription Name"
			exit
	}
  
  
    if($subscriptionID)
	{
		Write-output "Subscription Id is $subscriptionID"
	} else{
		Write-Output "Please Pass Valid Subscription ID"
			exit
	}
 try
 { 
    
    $cred = Get-AutomationPSCredential -Name $AutomationCredentialAssetName 
    
    Add-AzureAccount -Credential $cred
	
	Write-Output "Login Successful"
  
 }
 catch{
    
     Write-Output "Please Pass Valid AutomationPSCredential"
	 exit
 }
	
$ConfigurationBlobName = Get-AutomationVariable -Name "fwdConfigurationBlobName"
$PackageBlobName = Get-AutomationVariable -Name "fwdPackageBlobName"
# $StorageAccountName = Get-AutomationVariable -Name "fwdpkgstorageaccount"
# $StorageContainerName = Get-AutomationVariable -Name "fwdpkgstoragecontaineraccount"
$StorageAccountName = Get-AutomationVariable -Name "templatestorageaccount"
$StorageContainerName = Get-AutomationVariable -Name "templatecontainer"
	
$slot = $Params.parameters.fwddeploymentslot.value #staging or production
$timeStampFormat = "g"
  
$storageAccountType = Get-AutomationVariable -Name "fwdstorageaccounttype"
$Remoteusername = Get-AutomationVariable -Name "fwdremoteusername"
$Remoteuserpassword=Get-AutomationVariable -Name "fwdremoteuserpwd"

$primaryStorageAccountName1 = $Params.parameters.fwdprimaryaccountname1.value
$secondaryStorageAccountName1 = $Params.parameters.fwdsecondaryaccountname1.value
$primaryStorageAccountName2 = $Params.parameters.fwdprimaryaccountname2.value
$secondaryStorageAccountName2 = $Params.parameters.fwdsecondaryaccountname2.value
$primaryLocation = Get-AutomationVariable -Name "primarylocation"
$secondaryLocation = Get-AutomationVariable -Name "Secondarylocation"
$primarycloudService = $Params.parameters.fwdprimarycloudService.value
$deploymentLabelPrimary = "$primarycloudService - $(Get-Date -f $timeStampFormat)"

$secondarycloudService = $Params.parameters.fwdsecondarycloudService.value
$deploymentLabelSecondary = "$secondarycloudService - $(Get-Date -f $timeStampFormat)"

$ResourceGroupName = Get-AutomationVariable -Name "fwdresourcegroupname"
$ResourceGroupLocation = Get-AutomationVariable -Name "fwdresourcegrouplocation"
		
$verbosePreference = "Continue"

Write-Output "Getting Azure subscription name $subscriptionName and id $subscriptionID"
Get-AzureSubscription -SubscriptionName $subscriptionName
Write-Output "Finihsed getting Azure subscription"

# Select Azure subscription
Write-output "Selecting Azure Subscription..."
Select-AzureSubscription -SubscriptionName $subscriptionName
Write-Output "Selected Azure Subscription "

function Publish1()
{
   CreateStorageAccount1
   CreateStorageAccount2
   CreateCloudService1
      
  Write-Output "Selecting package location $packageLocation."
    
  Write-Output "$(Get-Date -f $timeStampFormat) - Publising Azure Deployment..."
  $deployment = Get-AzureDeployment -ServiceName $primarycloudService -Slot $slot -ErrorVariable a -ErrorAction silentlycontinue 

if ($a[0] -ne $null) {
    Write-Output "$(Get-Date -f $timeStampFormat) - No deployment is detected. Creating a new deployment. "
}

if ($deployment.Name -ne $null) 
{
    Write-Output "$(Get-Date -f $timeStampFormat) - Deployment exists in $primarycloudService.  Upgrading deployment."
    UpgradeDeployment1
} 
else 
{
    CreateNewDeployment1
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
    New-AzureStorageAccount -StorageAccountName $primaryStorageAccountName1 -Type $storageAccountType -Location $primaryLocation
  }
else
  {
     Write-output "Storage Account $primaryStorageAccountName1 already exists."
  }
    $strkey = (Get-AzureStorageKey -StorageAccountName $primaryStorageAccountName1).Primary
    $strCtxt =  New-AzureStorageContext -StorageAccountName $primaryStorageAccountName1 -StorageAccountKey $strkey
    Set-AzureStorageServiceMetricsProperty -MetricsLevel None -RetentionDays -1 -ServiceType Queue -MetricsType Hour -Context $strCtxt
    Set-AzureStorageServiceMetricsProperty -MetricsLevel None -RetentionDays -1 -ServiceType Blob -MetricsType Hour -Context $strCtxt
    Set-AzureStorageServiceMetricsProperty -MetricsLevel None -RetentionDays -1 -ServiceType Table -MetricsType Hour -Context $strCtxt
    Get-AzureStorageAccount -StorageAccountName $primaryStorageAccountName1
   
}

function CreateStorageAccount2()
{
  if (!(Test-AzureName -Storage $primaryStorageAccountName2))
  {  
    Write-Output "Creating Storage Account $primaryStorageAccountName2"
    New-AzureStorageAccount -StorageAccountName $primaryStorageAccountName2 -Type $storageAccountType -Location $primaryLocation
  }
else
  {
     Write-Output "Storage Account $primaryStorageAccountName2 already exists."
  }
     $strkey = (Get-AzureStorageKey -StorageAccountName $primaryStorageAccountName2).Primary
     $strCtxt =  New-AzureStorageContext -StorageAccountName $primaryStorageAccountName2 -StorageAccountKey $strkey
     Set-AzureStorageServiceMetricsProperty -MetricsLevel Service -RetentionDays -1 -ServiceType Queue -MetricsType Hour -Context $strCtxt
     Set-AzureStorageServiceMetricsProperty -MetricsLevel Service -RetentionDays -1 -ServiceType Blob -MetricsType Hour -Context $strCtxt
     Set-AzureStorageServiceMetricsProperty -MetricsLevel Service -RetentionDays -1 -ServiceType Table -MetricsType Hour -Context $strCtxt

     Get-AzureStorageAccount -StorageAccountName $primaryStorageAccountName2
}

function CreateCloudService1()
{
    Write-Output "Selecting Cloud Service.."
  if (!(Test-AzureName -Service $primarycloudService))
  {  
    Write-Output "Creating Cloud Service $primarycloudService"
    New-AzureService -ServiceName $primarycloudService -Location $primaryLocation
  }
  else
  {
    Write-Output "Cloud Service $primarycloudService already exists. So retrieving it"
    Get-AzureService -ServiceName $primarycloudService
  }
}

function CreateNewDeployment1()
{
	$subName = Get-AutomationVariable -Name "templateSubscriptionname"
    Write-Output "Selecting Azure Subscription $subName"
	Select-AzureSubscription -SubscriptionName  $subName
	Write-Output "Selected Azure Subscription $subName"
 
 	#Write-Output "Getting storage account..."
    #$StorageAccount = (Get-AzureStorageAccount -StorageAccountName $StorageAccountName).Label
    
    #Write-Output ('Setting the Azure Subscription and Storage Accounts')
    #Set-AzureSubscription  -SubscriptionName $templatesubsid -CurrentStorageAccount $StorageAccount
    
    try
    {
        $Conn = Get-AutomationConnection -Name AzureRunBookDevConnection
        Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
            -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint 
        $templateSubscriptionid = Get-AutomationVariable -Name "templateSubscriptionid"
        Set-AzureRmContext -SubscriptionId $templateSubscriptionid
        $Container = Get-AutomationVariable -Name "templatecontainer"  
        $templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
        $StorageAccount  = Get-AutomationVariable -Name "templatestorageaccount"
        $StorageAccountKey=(Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccount -ResourceGroupName $templateresourcegroupname).Key1
        $StorageContext = New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey
        
        #$StorageContext = SetStorageContext
        
        $TempFileLocation = "C:\$ConfigurationBlobName"
        $BlobFileLocation = "C:\$PackageBlobName"
     
        Write-Output ('CreateNewDeployment1: Downloading Service Configurations from Azure Storage')
    
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
    
    
 
    try{
         
     }
     catch{
         Write-Output "Error getting storage container."
    	 exit
     }
 
    Write-Output('Downloaded configuration file to: '+ $TempFileLocation)
    Write-Output('Downloaded package file to: '+ $BlobFileLocation)
    Write-Output('Getting Package Url from Azure Storage: '+ $PackageBlobName)
 
    # commenting out. not sure why this is needed
    # $blob = $(Get-AzureStorageBlob -Blob $PackageBlobName -Container $StorageContainerName)
    # $PackageUri = $blob.ICloudBlob.Uri.AbsoluteUri
 
    # Write-Output('Package Url: '+ $PackageUri)
    Write-Output('Attempting to Deploy the service')
          
    Write-Output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure Subscription"
    
    Write-Output "Getting Azure subscription $subscriptionName"
    Get-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Finihsed getting Azure subscription"


    # commenting this out. Not sure why it is here twice
    # Select Azure subscription
    # Write-output "Selecting Azure Subscription..."
    # Select-AzureSubscription -SubscriptionName $subscriptionName
    # Write-Output "Selected Azure Subscription "
    # Select Azure subscription

    Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccount $primarystorageAccountName1
            
    New-AzureDeployment `
        -Package $BlobFileLocation `
        -Configuration $TempFileLocation `
        -Slot Production `
        -Label $deploymentLabelPrimary `
        -ServiceName  $primarycloudService `
        -Verbose                
}

function UpgradeDeployment1()
{

    Write-Output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $templatesubsid
    Write-Output "Selected Azure Subscription"
  
    $StorageContext = SetStorageContext
 
    # commenting out
    #$StorageAccount = (Get-AzureStorageAccount -StorageAccountName $StorageAccountName).Label
    #Write-output ('Setting the Azure Subscription and Storage Accounts')
    #Set-AzureSubscription  -SubscriptionName $templatesubsid -CurrentStorageAccount $StorageAccount
    
    $Conn = Get-AutomationConnection -Name AzureRunBookDevConnection
    Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
        -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint 
    $templateSubscriptionid = Get-AutomationVariable -Name "templateSubscriptionid"
    Set-AzureRmContext -SubscriptionId $templateSubscriptionid
    $Container = Get-AutomationVariable -Name "templatecontainer"  
    $templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
    $StorageAccount  = Get-AutomationVariable -Name "templatestorageaccount"
    $StorageAccountKey=(Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccount -ResourceGroupName $templateresourcegroupname).Key1
    #$StorageContext = New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey
 
    $TempFileLocation = "C:\$ConfigurationBlobName"
    $BlobFileLocation = "C:\$PackageBlobName"
    Write-Output ('UpgradeDeployment1: Downloading Service Configurations from Azure Storage')
 
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

    #$blob = $(Get-AzureStorageBlob -Blob $PackageBlobName -Container $StorageContainerName)
    #$PackageUri = $blob.ICloudBlob.Uri.AbsoluteUri
    #Write-Output('Package Url: '+ $PackageUri)
  
    Write-Output('Attempting to Deploy the service')
          
    Write-Output "Selecting Azure Subscription..."
    #Select-AzureSubscription -SubscriptionName  $AzureSubscriptionName
    Select-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure Subscription"

    Write-Output "Getting Azure subscription $subscriptionName"
    Get-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure subscription"

    # Select Azure subscription
    Write-output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure Subscription "
 
    Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccount $primarystorageAccountName1

                 
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

function Publish2()
{
    
    CreateStorageAccount3
    CreateStorageAccount4
    Write-Output "Selecting Storage Account."
    CreateCloudService2
    
    
  Write-Output "Selected packageLocation $packageLocation."
  
    
    Write-Output "$(Get-Date -f $timeStampFormat) - Publising Azure Deployment..."
    $deployment = Get-AzureDeployment -ServiceName $secondarycloudService -Slot $slot -ErrorVariable a -ErrorAction silentlycontinue 

if ($a[0] -ne $null) {
    Write-Output "$(Get-Date -f $timeStampFormat) - No deployment is detected. Creating a new deployment. "
}

 if ($deployment.Name -ne $null) {
    Write-Output "$(Get-Date -f $timeStampFormat) - Deployment exists in $secondarycloudService.  Upgrading deployment."
    UpgradeDeployment2
} else {
    CreateNewDeployment2
Write-Output "Completed with Deployment."
    $securePassword2 = ConvertTo-SecureString $Remoteuserpassword -AsPlainText -Force
    $expiry = $(Get-Date).AddDays(10)
    $credential2 = New-Object System.Management.Automation.PSCredential $Remoteusername,$securepassword2
     
    Set-AzureServiceRemoteDesktopExtension -ServiceName $secondarycloudService -Credential $credential2 -Expiration $expiry
    }
    Get-AzureServiceRemoteDesktopExtension -ServiceName $secondarycloudService
    
    Write-Output "Completed Worker Role Deployment Successfully."
}

function CreateStorageAccount3()
{
  if (!(Test-AzureName -Storage $secondaryStorageAccountName1))
  {  
    Write-Output "Creating Storage Account $secondaryStorageAccountName1"
    New-AzureStorageAccount -StorageAccountName $secondaryStorageAccountName1 -Type $storageAccountType -Location $secondaryLocation
  }
else
  {
     Write-Output "Storage Account $secondaryStorageAccountName1 already exists."
  }
    $strkey = (Get-AzureStorageKey -StorageAccountName $secondaryStorageAccountName1).secondary
    $strCtxt =  New-AzureStorageContext -StorageAccountName $secondaryStorageAccountName1 -StorageAccountKey $strkey
    Set-AzureStorageServiceMetricsProperty -MetricsLevel None -RetentionDays -1 -ServiceType Queue -MetricsType Hour -Context $strCtxt
    Set-AzureStorageServiceMetricsProperty -MetricsLevel None -RetentionDays -1 -ServiceType Blob -MetricsType Hour -Context $strCtxt
    Set-AzureStorageServiceMetricsProperty -MetricsLevel None -RetentionDays -1 -ServiceType Table -MetricsType Hour -Context $strCtxt
    Get-AzureStorageAccount -StorageAccountName $secondaryStorageAccountName1
}

function CreateStorageAccount4()
{
  if (!(Test-AzureName -Storage $secondaryStorageAccountName2))
  {  
    Write-Output "Creating Storage Account $secondaryStorageAccountName2"
    New-AzureStorageAccount -StorageAccountName $secondaryStorageAccountName2 -Type $storageAccountType -Location $secondaryLocation
  }
else
  {
     Write-Output "Storage Account $secondaryStorageAccountName2 already exists."
  }
     $strkey = (Get-AzureStorageKey -StorageAccountName $secondaryStorageAccountName2).secondary
     $strCtxt =  New-AzureStorageContext -StorageAccountName $secondaryStorageAccountName2 -StorageAccountKey $strkey
     Set-AzureStorageServiceMetricsProperty -MetricsLevel Service -RetentionDays -1 -ServiceType Queue -MetricsType Hour -Context $strCtxt
     Set-AzureStorageServiceMetricsProperty -MetricsLevel Service -RetentionDays -1 -ServiceType Blob -MetricsType Hour -Context $strCtxt
     Set-AzureStorageServiceMetricsProperty -MetricsLevel Service -RetentionDays -1 -ServiceType Table -MetricsType Hour -Context $strCtxt
     Get-AzureStorageAccount -StorageAccountName $secondaryStorageAccountName2
}

function CreateCloudService2()
{
    Write-Output "started  with Cloud Service."
  if (!(Test-AzureName -Service $secondarycloudService))
  {  
    Write-Output "Creating Cloud Service $secondarycloudService"
    New-AzureService -ServiceName $secondarycloudService -Location $secondaryLocation
  }
  else
  {
    Write-Output "Cloud Service $secondarycloudService already exists. So retrieving it"
    Get-AzureService -ServiceName $secondarycloudService
  }
}

function CreateNewDeployment2()
{
    Write-Output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName  $templatesubsid
    Write-Output "Selected Azure Subscription"

    #$StorageContext = SetStorageContext
 
    # $StorageAccount = (Get-AzureStorageAccount -StorageAccountName $StorageAccountName).Label
    # Write-Output ('Setting the Azure Subscription and Storage Accounts')
    # Set-AzureSubscription  -SubscriptionName $templatesubsid -CurrentStorageAccount $StorageAccount
    
    $Conn = Get-AutomationConnection -Name AzureRunBookDevConnection
    Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
        -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint 
    $templateSubscriptionid = Get-AutomationVariable -Name "templateSubscriptionid"
    Set-AzureRmContext -SubscriptionId $templateSubscriptionid
    $Container = Get-AutomationVariable -Name "templatecontainer"  
    $templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
    $StorageAccount  = Get-AutomationVariable -Name "templatestorageaccount"
    $StorageAccountKey=(Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccount -ResourceGroupName $templateresourcegroupname).Key1
    #$StorageContext = New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey
 
    $TempFileLocation = "C:\$ConfigurationBlobName"
    $BlobFileLocation = "C:\$PackageBlobName"

    Write-Output ('CreateNewDeployment2: Downloading Service Configurations from Azure Storage')
 
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
 
        # $blob = $(Get-AzureStorageBlob -Blob $PackageBlobName -Container $StorageContainerName)
        # $PackageUri = $blob.ICloudBlob.Uri.AbsoluteUri
        # Write-Output('Package Url: '+ $PackageUri)
      
        Write-Output('Attempting to Deploy the service')

    Write-Output "Getting Azure subscription $subscriptionName"
    Get-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure subscription"

    # Select Azure subscription
    Write-output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure Subscription "
 
    Set-AzureSubscription `
            -SubscriptionName $subscriptionName `
            -CurrentStorageAccount $secondarystorageaccountName1
    
     New-AzureDeployment `
            -Package $BlobFileLocation `
            -Configuration $TempFileLocation `
            -Slot Production `
            -Label $deploymentLabelsecondary `
            -ServiceName  $secondarycloudService `
            -Verbose
                
    Write-Output('Attempting to Update an Existing Deployment')
}

function UpgradeDeployment2()
{
    Write-Output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName  $templatesubsid
    Write-Output "Selected Azure Subscription"
 
    $StorageAccount = (Get-AzureStorageAccount -StorageAccountName $StorageAccountName).Label

    Write-Output ('Setting the Azure Subscription and Storage Accounts')

    Set-AzureSubscription  -SubscriptionName $templatesubsid -CurrentStorageAccount $StorageAccount

    $TempFileLocation = "C:\$ConfigurationBlobName"
    
    $BlobFileLocation = "C:\$PackageBlobName"

    Write-Output ('Downloading Service Configurations from Azure Storage')

    Get-AzureStorageBlobContent `
        -Container $StorageContainerName `
        -Blob  $ConfigurationBlobName `
        -Destination $TempFileLocation `
        -Force
            
    Get-AzureStorageBlobContent `
        -Container $StorageContainerName `
        -Blob  $PackageBlobName `
        -Destination $BlobFileLocation `
        -Force

    Write-Output('Downloaded Configuration File: '+ $TempFileLocation)
 
    
    Write-Output('Downloaded Configuration File: '+ $BlobFileLocation)
 
    Write-Output('Getting Package Url from Azure Storage: '+ $PackageBlobName)

    $blob = $(Get-AzureStorageBlob -Blob $PackageBlobName -Container $StorageContainerName)

    $PackageUri = $blob.ICloudBlob.Uri.AbsoluteUri

    Write-Output('Package Url: '+ $PackageUri)

  
    Write-Output('Attempting to Deploy the service')

        

    Write-Output "Getting Azure subscription $subscriptionName"
    Get-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure subscription"

    # Select Azure subscription
    Write-output "Selecting Azure Subscription..."
    Select-AzureSubscription -SubscriptionName $subscriptionName
    Write-Output "Selected Azure Subscription "
 
    Set-AzureSubscription `
            -SubscriptionName $subscriptionName `
            -CurrentStorageAccount $secondarystorageAccountName1

                 
    Write-Output('Attempting to Update an Existing Deployment')
        Set-AzureDeployment `
            -Package $BlobFileLocation `
            -Configuration $TempFileLocation `
            -Slot Production `
            -Mode Simultaneous `
            -Label $deploymentLabelsecondary `
            -ServiceName  $secondarycloudService `
            -Upgrade `
            -Force `
            -Verbose
            
    Write-Output('Attempting to Update an Existing Deployment')
}

function SetStorageContext()
{
    $Conn = Get-AutomationConnection -Name AzureRunBookDevConnection
    Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
        -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint 
    $templateSubscriptionid = Get-AutomationVariable -Name "templateSubscriptionid"
    Set-AzureRmContext -SubscriptionId $templateSubscriptionid
    $Container = Get-AutomationVariable -Name "templatecontainer"  
    $templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
    $StorageAccount  = Get-AutomationVariable -Name "templatestorageaccount"
    $StorageAccountKey=(Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccount -ResourceGroupName $templateresourcegroupname).Key1
    $StorageContext = New-AzureStorageContext $StorageAccount -StorageAccountKey $StorageAccountKey
    
    $StorageContext
}

try{
    Publish1
    Publish2
}catch{
    throw
    Break
}
