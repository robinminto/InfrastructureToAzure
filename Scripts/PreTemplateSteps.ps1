Param
    (
        [Parameter(Mandatory=$true)]
        $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        $SolutionPath,

        [Parameter(Mandatory=$true)]
        $DeploymentID,

        [Parameter(Mandatory=$true)]
        $Region
)



# Remove resource group if it already exists - this takes time, consider creatng unique deployment ID each time
Remove-AzureRmResourceGroup -Name "WinOps$DeploymentID" -ErrorAction SilentlyContinue -Force 


# Create new Resource Group
New-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName   -Location $Region

# create new storage account
$stor = New-AzureRmStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name "artifacts$($DeploymentID.ToLower())" `
        -Type Standard_LRS `
        -Location $Region


# Create new container
Azure.Storage\New-AzureStorageContainer -Container $DeploymentID.ToLower() -Context $stor.Context 


# Get SAS token for containr, valid for a  day
$SASToken = New-AzureStorageContainerSASToken `
    -Name $DeploymentID.ToLower() `
    -Permission r  `
    -Context $stor.Context `
    -ExpiryTime (Get-Date).AddDays(1)


# upload artifacts
ls -File "$SolutionPath\DSC\" -Recurse `
    | Azure.Storage\Set-AzureStorageBlobContent -Container  $DeploymentID.ToLower()   -Context $stor.Context -Force 


# create automation account
$automationAccount = New-AzureRMAutomationAccount `
    –ResourceGroupName $ResourceGroupName `
    –Location $Region `
    –Name "WinOpsAutomation$DeploymentID"

    
# retrieve the automation account registration info
$automationRegInfo = Get-AzureRmAutomationRegistrationInfo `
     -AutomationAccountName $automationAccount.AutomationAccountName -ResourceGroupName $ResourceGroupName

#import modules required by configurations
[System.Collections.ArrayList]$jobs =  @()

foreach($module in Get-ChildItem -Path "$solutionPath\DSC\Modules" -Filter "*.zip"){


 $job =  New-AzureRmAutomationModule `
    -Name $module.Name.Replace(".zip","") `
    -ResourceGroupName   $ResourceGroupName `
    -AutomationAccountName $automationAccount.AutomationAccountName `
    -ContentLink "$($stor.PrimaryEndpoints.Blob.AbsoluteUri)$($DeploymentID.ToLower())/Modules/$($module.Name)$SASToken"
      $jobs.add($job) 

 }

 # wait for all modules to be provisioned
 foreach($job in $jobs){

    while(($job | Get-AzureRmAutomationModule).ProvisioningState  -ne "Succeeded"){
		sleep 5
	}

 }


# import configuration to be used by the VMs
[System.Collections.ArrayList]$jobs =  @()

foreach($config in Get-ChildItem -Path "$solutionPath\DSC\" -Filter "*.ps1"){

    Import-AzureRmAutomationDscConfiguration  `
        -ResourceGroupName $ResourceGroupName  –AutomationAccountName $automationAccount.AutomationAccountName `
        -SourcePath $config.FullName  `
        -Published –Force

   # Begin compilation of the configuration
   $job = Start-AzureRmAutomationDscCompilationJob `
        -ResourceGroupName $ResourceGroupName  –AutomationAccountName $automationAccount.AutomationAccountName `
        -ConfigurationName $config.Name.Replace(".ps1","")
    $jobs.add($job)  
 }
 
 # Wait until all configurations have compiled
 foreach($job in $jobs){

 while(($job | Get-AzureRmAutomationDscCompilationJob).Status -ne "Completed"){
	sleep 5
 }

 }

# save variables for VSTS use
Write-Host  "##vso[task.setvariable variable=AutomationRegistrationURL;]$($automationRegInfo.Endpoint)"
Write-Host  "##vso[task.setvariable variable=AutomationRegistrationKey;]$($automationRegInfo.PrimaryKey)"
Write-Host  "##vso[task.setvariable variable=SASToken;]$SASToken"
