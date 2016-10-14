Param
    (
        [Parameter(Mandatory=$true)]
        $ResourceGroupName,


        [Parameter(Mandatory=$true)]
        $SolutionPath,
     
        [Parameter(Mandatory=$true)]
        $Region
)


# Create new Resource Group
New-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName   -Location $Region -ErrorAction SilentlyContinue

$storageAccountName = (-join ([char[]](65..90+97..122)*100 | Get-Random -Count 8)).ToLower()

# create new storage account
$stor = New-AzureRmStorageAccount `
       -ResourceGroupName $ResourceGroupName `
       -Name $storageAccountName `
        -Type Standard_LRS `
       -Location $Region


# Create new container
Azure.Storage\New-AzureStorageContainer -Container "modules" -Context $stor.Context 


# Get SAS token for containr, valid for a  day
$SASToken = New-AzureStorageContainerSASToken `
    -Name "modules" `
    -Permission r  `
    -Context $stor.Context `
    -ExpiryTime (Get-Date).AddDays(1)


# upload artifacts
ls -File "$SolutionPath\DSC\Modules"  -Recurse `
    | Azure.Storage\Set-AzureStorageBlobContent -Container  "modules"   -Context $stor.Context -Force 


# create automation account
$automationAccount = New-AzureRMAutomationAccount `
    –ResourceGroupName $ResourceGroupName `
    –Location $Region `
    –Name "Automation$ResourceGroupName"

    
# retrieve the automation account registration info
$automationRegInfo = Get-AzureRmAutomationRegistrationInfo `
     -AutomationAccountName $automationAccount.AutomationAccountName -ResourceGroupName $ResourceGroupName

#import modules required by configurations
[System.Collections.ArrayList]$modulejobs =  @()

foreach($module in Get-ChildItem -Path "$solutionPath\DSC\Modules" -Filter "*.zip"){

	Write-Host "Creating Module:"  $module.Name
   
	$modulejobs.add((New-AzureRmAutomationModule `
		 -Name $module.Name.Replace(".zip","") `
		 -ResourceGroupName   $ResourceGroupName `
		 -AutomationAccountName $automationAccount.AutomationAccountName `
		 -ContentLink "$($stor.PrimaryEndpoints.Blob)modules/$($module.Name)$SASToken")) 

 }


 

# import configuration to be used by the VMs
[System.Collections.ArrayList]$configjobs =  @()

foreach($config in Get-ChildItem -Path "$solutionPath\DSC\" -Filter "*.ps1"){
	Write-Host "Creating Configuration:"  $config.Name

    Import-AzureRmAutomationDscConfiguration  `
        -ResourceGroupName $ResourceGroupName  –AutomationAccountName $automationAccount.AutomationAccountName `
        -SourcePath $config.FullName  `
        -Published –Force

   # Begin compilation of the configuration
   $configjob = 
    $configjobs.add((Start-AzureRmAutomationDscCompilationJob `
        -ResourceGroupName $ResourceGroupName  –AutomationAccountName $automationAccount.AutomationAccountName `
        -ConfigurationName $config.Name.Replace(".ps1","")))  
 }

 
  # wait for all modules to be provisioned
 foreach($modulejobs in $modulejobs){

    while(($modulejobs | Get-AzureRmAutomationModule).ProvisioningState  -ne "Succeeded"){
		sleep 5
	}

 }


 # Wait until all configurations have compiled
 foreach($configjobs in $configjobs){

	 while(($configjobs | Get-AzureRmAutomationDscCompilationJob).Status -ne "Completed"){
		sleep 5
	 }

 }



# save variables for VSTS use
Write-Host  "##vso[task.setvariable variable=AutomationRegistrationURL;]$($automationRegInfo.Endpoint)"
Write-Host  "##vso[task.setvariable variable=AutomationRegistrationKey;]$($automationRegInfo.PrimaryKey)"
Write-Host  "##vso[task.setvariable variable=SASToken;]$SASToken"
