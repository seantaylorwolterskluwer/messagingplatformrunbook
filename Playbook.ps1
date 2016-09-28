Param ( 
	
        [Parameter(Mandatory=$True)]
        [object]$WebhookData
	
    ) 
	
$WebhookBody = $WebhookData.RequestBody
$Params = ConvertFrom-Json -InputObject $WebhookBody
Write-Output "Json Data received is $WebhookBody"
	 
$subscriptionID =  $Params.parameters.Subscriptionid 
Write-Output "Destination subscription Id is $subscriptionID"

$templateSubscriptionId = Get-AutomationVariable -Name "templateSubscriptionid"
Write-Output "Template subscription Id is $templateSubscriptionId"   
 
$AutomationCredentialAssetName = $Params.parameters.AutomationCredentialAssetName
Write-Output "AutomationCredentialAssetName Id is $AutomationCredentialAssetName"
 
try
{ 
	$cred = Get-AutomationPSCredential -Name $AutomationCredentialAssetName
	Add-AzureRmAccount -Credential $cred -SubscriptionId $subscriptionID  
	Set-AzureRmContext -SubscriptionId $subscriptionID
}
catch
{
    Write-Output "Please Pass Valid AutomationPSCredential"
    exit
}
	  
try
{
	$SubObjectID  = Get-AutomationVariable -Name "SubObjectID"
	$RoleExists = Get-AzureRMRoleassignment -ObjectId $SubObjectID

	if($RoleExists){			    
		Write-Output "AzureRMRoleassignment already exists"
	}
	else
	{
		$ApplicationId = (Get-AzureRmADApplication -IdentifierUri "https://Runbook").ApplicationId
		New-AzureRmRoleAssignment -RoleDefinitionName owner -ServicePrincipalName $ApplicationId.Guid
		Write-Output "AzureRMRoleassignment Created successfully"
	}
}
catch
{     
	Write-Error "Error Occured during AzureRMRoleassignment" 
    exit
}   
 
Add-AzureRmAccount -Credential $cred -SubscriptionId $TemplateSubscriptionid  
Set-AzureRmContext -SubscriptionId $TemplateSubscriptionid 
 
$Container = Get-AutomationVariable -Name "templatecontainer"  
$templateresourcegroupname  = Get-AutomationVariable -Name "templateresourcegroupname"
$StorageAccountName = Get-AutomationVariable -Name "templatestorageaccount"
$ResourceGroupName = $Params.parameters.DeploymentResourceGroupName 
$TemplateStorageAccount = Get-AzureRmStorageAccountKey -Name $StorageAccountName -ResourceGroupName $templateresourcegroupname
$StorageAccountKey = $TemplateStorageAccount | Where-Object { $_.KeyName -eq 'key1' }
$StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey.Value

Set-AzureRmContext -SubscriptionId $subscriptionID 
 
$ResourceGroupLocation = Get-AutomationVariable -Name "primarylocation"
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop

$PrimaryTemplateFile = "EventHubPrmry.json"
$SecondaryTemplateFile = "EventHubScndry.json"
$PrimaryTemplateFile = New-AzureStorageBlobSASToken -Blob $PrimaryTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
$SecondaryTemplateFile = New-AzureStorageBlobSASToken -Blob $SecondaryTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
 
Write-Output "$PrimaryTemplateFile"
Write-Output "$SecondaryTemplateFile"
		
$HashTable = @{}
$HashTable['PRIMARYSERVICEBUSNAMESPACENAME'] = $Params.parameters.PRIMARYSERVICEBUSNAMESPACENAME 
$PRIMARYSERVICEBUSEVENTHUBNAME = Get-AutomationVariable -Name "PRIMARYSERVICEBUSEVENTHUBNAME"
$PRIMARYSERVICEBUSCONSUMERGROUPNAME1 = Get-AutomationVariable -Name "PRIMARYSERVICEBUSCONSUMERGROUPNAME1"
$PRIMARYSERVICEBUSCONSUMERGROUPNAME2 = Get-AutomationVariable -Name "PRIMARYSERVICEBUSCONSUMERGROUPNAME2"
$PRIMARYSERVICEBUSCONSUMERGROUPNAME3 = Get-AutomationVariable -Name "PRIMARYSERVICEBUSCONSUMERGROUPNAME3"
$partitionCount = Get-AutomationVariable -Name "partitionCount"
$primarylocation = Get-AutomationVariable -Name "primarylocation"
						
$HashTable.Add("PRIMARYSERVICEBUSEVENTHUBNAME",$PRIMARYSERVICEBUSEVENTHUBNAME)
$HashTable.Add("PRIMARYSERVICEBUSCONSUMERGROUPNAME1",$PRIMARYSERVICEBUSCONSUMERGROUPNAME1)
$HashTable.Add("PRIMARYSERVICEBUSCONSUMERGROUPNAME2",$PRIMARYSERVICEBUSCONSUMERGROUPNAME2)
$HashTable.Add("PRIMARYSERVICEBUSCONSUMERGROUPNAME3", $PRIMARYSERVICEBUSCONSUMERGROUPNAME3)
$HashTable.Add("partitionCount", $partitionCount)
$HashTable.Add("primarylocation",$primarylocation )
$HashTable
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $PrimaryTemplateFile -TemplateParameterObject   $HashTable -Force -Verbose

#---Get primary key from service bus ----------------------------
Add-AzureAccount -Credential $cred
Select-AzureSubscription -SubscriptionId $subscriptionID
$primaryServiceBusNamespace = $Params.parameters.PRIMARYSERVICEBUSNAMESPACENAME
$sbr = Get-AzureSBAuthorizationRule -Namespace $primaryServiceBusNamespace

# Get namespace manager
$NamespaceManager = [Microsoft.ServiceBus.NamespaceManager]::CreateFromConnectionString($sbr.ConnectionString);

# Check if event hub exists
if ($NamespaceManager.EventHubExists($PRIMARYSERVICEBUSEVENTHUBNAME))
{
    Write-Output "The [$PRIMARYSERVICEBUSEVENTHUBNAME] event hub already exists in the [$primaryServiceBusNamespace] namespace."  

    $ehub = $NamespaceManager.GetEventHub($PRIMARYSERVICEBUSEVENTHUBNAME)
    $rule = $ehub.Authorization | Where-Object { $_.KeyName -eq 'ReceiveRule' }
    $eventHubPrimaryKey = $rule.PrimaryKey
    Write-Output "Event Hub primary key is $eventHubPrimaryKey"
}
#----------------------------------------------


$HashTable = @{}
$HashTable['SecondarySERVICEBUSNAMESPACENAME'] = $Params.parameters.SecondarySERVICEBUSNAMESPACENAME 
$SecondarySERVICEBUSEVENTHUBNAME = Get-AutomationVariable -Name "PRIMARYSERVICEBUSEVENTHUBNAME"
$SecondarySERVICEBUSCONSUMERGROUPNAME1 = Get-AutomationVariable -Name "PRIMARYSERVICEBUSCONSUMERGROUPNAME1"
$SecondarySERVICEBUSCONSUMERGROUPNAME2 = Get-AutomationVariable -Name "PRIMARYSERVICEBUSCONSUMERGROUPNAME2"
$SecondarySERVICEBUSCONSUMERGROUPNAME3 = Get-AutomationVariable -Name "PRIMARYSERVICEBUSCONSUMERGROUPNAME3"
$partitionCount = Get-AutomationVariable -Name "partitionCount"
$Secondarylocation = Get-AutomationVariable -Name "Secondarylocation"
						
$HashTable.Add("SecondarySERVICEBUSEVENTHUBNAME",$PRIMARYSERVICEBUSEVENTHUBNAME)
$HashTable.Add("SecondarySERVICEBUSCONSUMERGROUPNAME1",$PRIMARYSERVICEBUSCONSUMERGROUPNAME1)
$HashTable.Add("SecondarySERVICEBUSCONSUMERGROUPNAME2",$PRIMARYSERVICEBUSCONSUMERGROUPNAME2)
$HashTable.Add("SecondarySERVICEBUSCONSUMERGROUPNAME3", $PRIMARYSERVICEBUSCONSUMERGROUPNAME3)
$HashTable.Add("partitionCount", $partitionCount)
$HashTable.Add("Secondarylocation",$Secondarylocation )
$HashTable
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $SecondaryTemplateFile -TemplateParameterObject $HashTable -Force -Verbose

#---Get primary key from service bus ----------------------------
#Add-AzureAccount -Credential $cred
#Select-AzureSubscription -SubscriptionId $subscriptionID
$secondaryServiceBusNamespace = $Params.parameters.SecondarySERVICEBUSNAMESPACENAME
$sbr = Get-AzureSBAuthorizationRule -Namespace $secondaryServiceBusNamespace

# Get namespace manager
$NamespaceManager = [Microsoft.ServiceBus.NamespaceManager]::CreateFromConnectionString($sbr.ConnectionString);

# Check if event hub exists
if ($NamespaceManager.EventHubExists($SecondarySERVICEBUSEVENTHUBNAME))
{
    Write-Output "The [$SecondarySERVICEBUSEVENTHUBNAME] event hub already exists in the [$secondaryServiceBusNamespace] namespace."  

    $ehub = $NamespaceManager.GetEventHub($SecondarySERVICEBUSEVENTHUBNAME)
    $rule = $ehub.Authorization | Where-Object { $_.KeyName -eq 'ReceiveRule' }
    $eventHubSecondaryKey = $rule.PrimaryKey
    Write-Output "Event Hub secondary key is $eventHubSecondaryKey"
}
#----------------------------------------------
                                 
Write-Output "Deployed EventHub Successfully"
#---------------------------------------------------------------------------------------

#--------BEGIN APPINSIGHTS----------------------------------------------------------
$PrimaryTemplateFile = "AppInsightsPrimary.json"
$SecondaryTemplateFile = "AppInsightsSecondary.json"
$PrimaryTemplateFile = New-AzureStorageBlobSASToken -Blob $PrimaryTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
$SecondaryTemplateFile = New-AzureStorageBlobSASToken -Blob $SecondaryTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
 
Write-Output "$PrimaryTemplateFile"
Write-Output "$SecondaryTemplateFile"
		
$HashTable = @{}
$HashTable['ApplicationInsightsPrimary'] = $Params.parameters.ApplicationInsightsPrimary 

$aiLocation = Get-AutomationVariable -Name "aiLocation"

$HashTable.Add("aiLocation",$aiLocation)

New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $PrimaryTemplateFile -TemplateParameterObject $HashTable -Force -Verbose

$HashTable = @{}
$HashTable['ApplicationInsightsSecondary'] = $Params.parameters.ApplicationInsightsSecondary

$aiLocation = Get-AutomationVariable -Name "aiLocation"

$HashTable.Add("aiLocation",$aiLocation)

New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $SecondaryTemplateFile -TemplateParameterObject $HashTable -Force -Verbose
#----------------------------------------------
Write-Output "Deployed AppInsights Successfully"
#---------------------------------------------------------------------------------------


#--------BEGIN SERVICE BUS----------------------------------------------------------
$PrimaryQueuesTemplateFile = "ServiceBusForPrimaryQueues.json"
$PrimaryQueues_UpdateTemplateFile = "ServiceBusForPrimaryQueues_Update.json"
$SecondaryQueuesTemplateFile = "ServiceBusForSecondaryQueues.json"
$SecondaryQueues_UpdateTemplateFile = "ServiceBusForSecondaryQueues_Update.json"
 
 $PrimaryQueuesTemplateFile = New-AzureStorageBlobSASToken -Blob $PrimaryQueuesTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
 $PrimaryQueues_UpdateTemplateFile = New-AzureStorageBlobSASToken -Blob $PrimaryQueues_UpdateTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
 
 $SecondaryQueuesTemplateFile = New-AzureStorageBlobSASToken -Blob $SecondaryQueuesTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
 $SecondaryQueues_UpdateTemplateFile = New-AzureStorageBlobSASToken -Blob $SecondaryQueues_UpdateTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
 
$HashTable = @{}
$HashTable['primaryServiceBusNamespace'] = $Params.parameters.primaryServiceBusNamespace 
$HashTable['secondaryServiceBusNamespace'] = $Params.parameters.secondaryServiceBusNamespace 

$serviceBusApiVersion = Get-AutomationVariable -Name "serviceBusApiVersion"
$primarylocation = Get-AutomationVariable -Name "primarylocation"
$secondarylocation = Get-AutomationVariable -Name "secondarylocation"
$primaryServiceBusQueue_alerts = Get-AutomationVariable -Name "primaryServiceBusQueue_alerts"
$primaryServiceBusQueue_emails = Get-AutomationVariable -Name "primaryServiceBusQueue_emails"
$primaryServiceBusQueue_errors = Get-AutomationVariable -Name "primaryServiceBusQueue_errors"
$secondaryServiceBusQueue_alerts = Get-AutomationVariable -Name "primaryServiceBusQueue_alerts"
$secondaryServiceBusQueue_emails = Get-AutomationVariable -Name "primaryServiceBusQueue_emails"
$secondaryServiceBusQueue_errors = Get-AutomationVariable -Name "primaryServiceBusQueue_errors"
$defaultMessageTimeToLive7Days = Get-AutomationVariable -Name "defaultMessageTimeToLive7Days"
$maxSizeInMegabytes16GB = Get-AutomationVariable -Name "maxSizeInMegabytes16GB"
$deadLetteringOnMessageExpirationTrue = Get-AutomationVariable -Name "deadLetteringOnMessageExpirationTrue"
$duplicateDetectionHistoryTimeWindow5Min = Get-AutomationVariable -Name "duplicateDetectionHistoryTimeWindow5Min"
$lockDuration30Sec = Get-AutomationVariable -Name "lockDuration30Sec"
$maxDeliveryCount10 = Get-AutomationVariable -Name "maxDeliveryCount10"
$defaultMessageTimeToLive14Days = Get-AutomationVariable -Name "defaultMessageTimeToLive14Days"
$maxSizeInMegabytes32GB = Get-AutomationVariable -Name "maxSizeInMegabytes32GB"
$deadLetteringOnMessageExpirationFalse = Get-AutomationVariable -Name "deadLetteringOnMessageExpirationFalse"
$duplicateDetectionHistoryTimeWindow10Min = Get-AutomationVariable -Name "duplicateDetectionHistoryTimeWindow10Min"
							
$HashTable.Add("serviceBusApiVersion",$serviceBusApiVersion)
$HashTable.Add("primarylocation",$primarylocation)
$HashTable.Add("secondarylocation",$Secondarylocation)
$HashTable.Add("primaryServiceBusQueue_alerts",$primaryServiceBusQueue_alerts)
$HashTable.Add("primaryServiceBusQueue_emails",$primaryServiceBusQueue_emails)
$HashTable.Add("primaryServiceBusQueue_errors",$primaryServiceBusQueue_errors)
$HashTable.Add("secondaryServiceBusQueue_alerts",$primaryServiceBusQueue_alerts)
$HashTable.Add("secondaryServiceBusQueue_emails",$primaryServiceBusQueue_emails)
$HashTable.Add("secondaryServiceBusQueue_errors",$primaryServiceBusQueue_errors)
$HashTable.Add("defaultMessageTimeToLive7Days",$defaultMessageTimeToLive7Days)
$HashTable.Add("maxSizeInMegabytes16GB",$maxSizeInMegabytes16GB)
$HashTable.Add("deadLetteringOnMessageExpirationTrue",$deadLetteringOnMessageExpirationTrue)
$HashTable.Add("duplicateDetectionHistoryTimeWindow5Min",$duplicateDetectionHistoryTimeWindow5Min)
$HashTable.Add("lockDuration30Sec",$lockDuration30Sec)
$HashTable.Add("maxDeliveryCount10",$maxDeliveryCount10)
$HashTable.Add("defaultMessageTimeToLive14Days",$defaultMessageTimeToLive14Days)
$HashTable.Add("maxSizeInMegabytes32GB",$maxSizeInMegabytes32GB)
$HashTable.Add("deadLetteringOnMessageExpirationFalse",$deadLetteringOnMessageExpirationFalse)
$HashTable.Add("duplicateDetectionHistoryTimeWindow10Min",$duplicateDetectionHistoryTimeWindow10Min)
	
$HashTable

New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $PrimaryQueuesTemplateFile -TemplateParameterObject   $HashTable -Force -Verbose

$HashTable = @{}
$HashTable['primaryServiceBusNamespace'] = $Params.parameters.primaryServiceBusNamespace 
$HashTable['secondaryServiceBusNamespace'] = $Params.parameters.secondaryServiceBusNamespace 

$serviceBusApiVersion = Get-AutomationVariable -Name "serviceBusApiVersion"
$primarylocation = Get-AutomationVariable -Name "primarylocation"
$secondarylocation = Get-AutomationVariable -Name "secondarylocation"
$primaryServiceBusQueue_alerts = Get-AutomationVariable -Name "primaryServiceBusQueue_alerts"
$primaryServiceBusQueue_emails = Get-AutomationVariable -Name "primaryServiceBusQueue_emails"
$primaryServiceBusQueue_errors = Get-AutomationVariable -Name "primaryServiceBusQueue_errors"
$secondaryServiceBusQueue_alerts = Get-AutomationVariable -Name "primaryServiceBusQueue_alerts"
$secondaryServiceBusQueue_emails = Get-AutomationVariable -Name "primaryServiceBusQueue_emails"
$secondaryServiceBusQueue_errors = Get-AutomationVariable -Name "primaryServiceBusQueue_errors"
$defaultMessageTimeToLive7Days = Get-AutomationVariable -Name "defaultMessageTimeToLive7Days"
$maxSizeInMegabytes16GB = Get-AutomationVariable -Name "maxSizeInMegabytes16GB"
$deadLetteringOnMessageExpirationTrue = Get-AutomationVariable -Name "deadLetteringOnMessageExpirationTrue"
$duplicateDetectionHistoryTimeWindow5Min = Get-AutomationVariable -Name "duplicateDetectionHistoryTimeWindow5Min"
$lockDuration30Sec = Get-AutomationVariable -Name "lockDuration30Sec"
$maxDeliveryCount10 = Get-AutomationVariable -Name "maxDeliveryCount10"
$defaultMessageTimeToLive14Days = Get-AutomationVariable -Name "defaultMessageTimeToLive14Days"
$maxSizeInMegabytes32GB = Get-AutomationVariable -Name "maxSizeInMegabytes32GB"
$deadLetteringOnMessageExpirationFalse = Get-AutomationVariable -Name "deadLetteringOnMessageExpirationFalse"
$duplicateDetectionHistoryTimeWindow10Min = Get-AutomationVariable -Name "duplicateDetectionHistoryTimeWindow10Min"
							
$HashTable.Add("serviceBusApiVersion",$serviceBusApiVersion)
$HashTable.Add("primarylocation",$primarylocation)
$HashTable.Add("secondarylocation",$Secondarylocation)
$HashTable.Add("primaryServiceBusQueue_alerts",$primaryServiceBusQueue_alerts)
$HashTable.Add("primaryServiceBusQueue_emails",$primaryServiceBusQueue_emails)
$HashTable.Add("primaryServiceBusQueue_errors",$primaryServiceBusQueue_errors)
$HashTable.Add("secondaryServiceBusQueue_alerts",$primaryServiceBusQueue_alerts)
$HashTable.Add("secondaryServiceBusQueue_emails",$primaryServiceBusQueue_emails)
$HashTable.Add("secondaryServiceBusQueue_errors",$primaryServiceBusQueue_errors)
$HashTable.Add("defaultMessageTimeToLive7Days",$defaultMessageTimeToLive7Days)
$HashTable.Add("maxSizeInMegabytes16GB",$maxSizeInMegabytes16GB)
$HashTable.Add("deadLetteringOnMessageExpirationTrue",$deadLetteringOnMessageExpirationTrue)
$HashTable.Add("duplicateDetectionHistoryTimeWindow5Min",$duplicateDetectionHistoryTimeWindow5Min)
$HashTable.Add("lockDuration30Sec",$lockDuration30Sec)
$HashTable.Add("maxDeliveryCount10",$maxDeliveryCount10)
$HashTable.Add("defaultMessageTimeToLive14Days",$defaultMessageTimeToLive14Days)
$HashTable.Add("maxSizeInMegabytes32GB",$maxSizeInMegabytes32GB)
$HashTable.Add("deadLetteringOnMessageExpirationFalse",$deadLetteringOnMessageExpirationFalse)
$HashTable.Add("duplicateDetectionHistoryTimeWindow10Min",$duplicateDetectionHistoryTimeWindow10Min)
$HashTable
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $SecondaryQueuesTemplateFile -TemplateParameterObject    $HashTable -Force -Verbose

Write-Output "Deployed Service Bus Successfully"
#--------END SERVICE BUS----------------------------------------------------------

#-------BEGIN TABLE STORAGE------------------------------------------------------------
Write-Output "Starting deployment of table storage tables"
$location1 = Get-AutomationVariable -Name "primarylocation"
$location2 =  Get-AutomationVariable -Name "Secondarylocation"

$PrimaryAccountName = $Params.parameters.primaryaccountname 
$SecondaryAccountName =$Params.parameters.secondaryaccountname 

$accountype = Get-AutomationVariable -Name "storageaccounttype"

$PrimarytableName1 = Get-AutomationVariable -Name "PrimarytableName1"
$PrimarytableName2 = Get-AutomationVariable -Name "PrimarytableName2"
$PrimarytableName3 = Get-AutomationVariable -Name "PrimarytableName3"
$SecondarytableName1 =Get-AutomationVariable -Name "SecondarytableName1"
$SecondarytableName2 = Get-AutomationVariable -Name "SecondarytableName2"
$SecondarytableName3 = Get-AutomationVariable -Name "SecondarytableName3"

$resource =  Find-AzureRmResource -ResourceType "Microsoft.Storage/storageAccounts" -ResourceNameContains  $PrimaryAccountName

if($resource -eq $null)
{
	Write-Output "Creating Storage Account $PrimaryAccountName"

	New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $PrimaryAccountName -location $location1 -AccountType $accountype

	$tempStorageAccount = Get-AzureRmStorageAccountKey -Name $PrimaryAccountName -ResourceGroupName $ResourceGroupName
	$tempPrimaryStorageAccountKey = $tempStorageAccount | Where-Object { $_.KeyName -eq 'key1' }
	$PrimaryStorageAccountKey = $tempPrimaryStorageAccountKey.Value
	Write-Output "Primary storage account key = " $PrimaryStorageAccountKey

	$Ctx1 = New-AzureStorageContext $PrimaryAccountName -StorageAccountKey $PrimaryStorageAccountKey

	New-AzureStorageTable -Name $PrimarytableName1 -Context $Ctx1
	New-AzureStorageTable -Name $PrimarytableName2 -Context $Ctx1
	New-AzureStorageTable -Name $PrimarytableName3 -Context $Ctx1
}
else
{
	Write-Output "Storage Account $PrimaryAccountName already exists."    
	
	$tempStorageAccount = Get-AzureRmStorageAccountKey -Name $PrimaryAccountName -ResourceGroupName $ResourceGroupName
	$tempPrimaryStorageAccountKey = $tempStorageAccount | Where-Object { $_.KeyName -eq 'key1' }
	$PrimaryStorageAccountKey = $tempPrimaryStorageAccountKey.Value
	Write-Output "Primary storage account key = " $PrimaryStorageAccountKey

	$Ctx1 = New-AzureStorageContext $PrimaryAccountName -StorageAccountKey $PrimaryStorageAccountKey

	New-AzureStorageTable -Name $PrimarytableName1 -Context $Ctx1
	New-AzureStorageTable -Name $PrimarytableName2 -Context $Ctx1
	New-AzureStorageTable -Name $PrimarytableName3 -Context $Ctx1 
}

$resource =  Find-AzureRmResource -ResourceType "Microsoft.Storage/storageAccounts" -ResourceNameContains  $SecondaryAccountName
  
if($resource -eq $null)
{
	Write-Output "Creating Storage Account $SecondaryAccountName"

	New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $SecondaryAccountName -location $location2 -AccountType  $accountype

	$tempStorageAccount = Get-AzureRmStorageAccountKey -Name $SecondaryAccountName -ResourceGroupName $ResourceGroupName
	$tempPrimaryStorageAccountKey = $tempStorageAccount | Where-Object { $_.KeyName -eq 'key1' }
	$SecondaryStorageAccountKey = $tempPrimaryStorageAccountKey.Value
	Write-Output "Secondary storage account key = " $SecondaryStorageAccountKey    
	
	$Ctx2 = New-AzureStorageContext $SecondaryAccountName -StorageAccountKey $SecondaryStorageAccountKey

	New-AzureStorageTable -Name $SecondarytableName1 -Context $Ctx2
	New-AzureStorageTable -Name $SecondarytableName2 -Context $Ctx2
	New-AzureStorageTable -Name $SecondarytableName3 -Context $Ctx2
}   
else
{
	Write-Output "Storage Account $SecondaryAccountName already exists."   
	
	$tempStorageAccount = Get-AzureRmStorageAccountKey -Name $SecondaryAccountName -ResourceGroupName $ResourceGroupName
	$tempPrimaryStorageAccountKey = $tempStorageAccount | Where-Object { $_.KeyName -eq 'key1' }
	$SecondaryStorageAccountKey = $tempPrimaryStorageAccountKey.Value
	Write-Output "Secondary storage account key = " $SecondaryStorageAccountKey    
	
	$Ctx2 = New-AzureStorageContext $SecondaryAccountName -StorageAccountKey $SecondaryStorageAccountKey

	New-AzureStorageTable -Name $SecondarytableName1 -Context $Ctx2
	New-AzureStorageTable -Name $SecondarytableName2 -Context $Ctx2
	New-AzureStorageTable -Name $SecondarytableName3 -Context $Ctx2  
}        

Write-Output "Deployed storage tables successfully"
#------END TABLE STORAGE-----------------------------------------------

# ---- Stream Analytics Jobs-------------------------------------------------------------------------------
#4.1 ARM files and Azure Storage account
Write-Output "Starting deployment of stream analytics jobs"
$PrimaryTemplateFile = "StreamAnalyticsSC.json"    
$SecondaryTemplateFile = "StreamAnalyticsWest.json"
$JobStartDate = Get-Date -Format o
 
$PrimaryTemplateFile = New-AzureStorageBlobSASToken -Blob $PrimaryTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r 
$SecondaryTemplateFile = New-AzureStorageBlobSASToken -Blob $SecondaryTemplateFile -Container $Container -Context $StorageContext -FullUri -Permission r
 
$HashTable = @{}
$HashTable['jobName'] = $Params.parameters.streamanalyticsprimary 

$jobLocation = Get-AutomationVariable -Name "primarylocation"	
$outputpartitionkeyName = Get-AutomationVariable -Name "outputpartitionkeyName"
$outputRowkeyName = Get-AutomationVariable -Name "outputRowkeyName"	
$inputEventHubName = Get-AutomationVariable -Name "inputEventHubName"
$inputEventHubConsumerGroupName = Get-AutomationVariable -Name "inputEventHubConsumerGroupName"
$inputEventHubSharedAccessPolicyName = Get-AutomationVariable -Name "inputEventHubSharedAccessPolicyName"

$HashTable.Add("jobLocation",$primarylocation)	
$HashTable.Add("outputStorageAccountKey",$PrimaryStorageAccountKey)
$HashTable.Add("outputTableName",$PrimarytableName1)
$HashTable.Add("outputpartitionkeyName",$outputpartitionkeyName)
$HashTable.Add("outputRowkeyName",$outputRowkeyName)
$HashTable.Add("inputServiceBusNamespace",$Params.parameters.PRIMARYSERVICEBUSNAMESPACENAME )	
$HashTable.Add("outputStorageAccountName",$Params.parameters.primaryaccountname )
$HashTable.Add("inputEventHubName",$inputEventHubName)
$HashTable.Add("inputEventHubConsumerGroupName",$inputEventHubConsumerGroupName)
$HashTable.Add("inputEventHubSharedAccessPolicyName",$inputEventHubSharedAccessPolicyName)
$HashTable.Add("inputEventHubSharedAccessPolicyKey",$eventHubPrimaryKey)

$HashTable
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $PrimaryTemplateFile -TemplateParameterObject  $HashTable -Force -Verbose
Start-AzureRmStreamAnalyticsJob -ResourceGroupName $ResourceGroupName -Name $Params.parameters.streamanalyticsprimary #-OutputStartMode "JobStartTime" -OutputStartTime $JobStartDate

$HashTable = @{}
$HashTable['jobName'] = $Params.parameters.streamanalyticssecondary 

$Secondary_jobLocation = Get-AutomationVariable -Name "Secondarylocation"
$Secondary_outputpartitionkeyName = Get-AutomationVariable -Name "outputpartitionkeyName"
$Secondary_outputRowkeyName = Get-AutomationVariable -Name "outputRowkeyName"
$Secondary_inputEventHubName = Get-AutomationVariable -Name "inputEventHubName"
$Secondary_inputEventHubConsumerGroupName = Get-AutomationVariable -Name "inputEventHubConsumerGroupName"
$Secondary_inputEventHubSharedAccessPolicyName = Get-AutomationVariable -Name "inputEventHubSharedAccessPolicyName"
			
$HashTable.Add("jobLocation",$Secondarylocation)	
$HashTable.Add("outputStorageAccountKey",$SecondaryStorageAccountKey)
$HashTable.Add("outputTableName",$SecondarytableName1)
$HashTable.Add("outputpartitionkeyName",$outputpartitionkeyName)
$HashTable.Add("outputRowkeyName",$outputRowkeyName)
$HashTable.Add("inputServiceBusNamespace",$Params.parameters.SecondarySERVICEBUSNAMESPACENAME )	
$HashTable.Add("outputStorageAccountName",$Params.parameters.secondaryaccountname )
$HashTable.Add("inputEventHubName",$inputEventHubName)
$HashTable.Add("inputEventHubConsumerGroupName",$inputEventHubConsumerGroupName)
$HashTable.Add("inputEventHubSharedAccessPolicyName",$inputEventHubSharedAccessPolicyName)
$HashTable.Add("inputEventHubSharedAccessPolicyKey", $eventHubSecondaryKey)

$HashTable
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $SecondaryTemplateFile -TemplateParameterObject   $HashTable -Force -Verbose
Start-AzureRmStreamAnalyticsJob -ResourceGroupName $ResourceGroupName -Name $Params.parameters.streamanalyticssecondary #-OutputStartMode "JobStartTime" -OutputStartTime $JobStartDate
  
Write-Output "Deployed stream analytics successfully"
Write-Output "Finished running script"