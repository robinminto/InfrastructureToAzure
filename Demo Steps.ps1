#
# Automated infrastructure Steps
#

#region Prep
$solutionPath = "C:\Users\marrobi\Source\Repos\InfrastructureToAzure\"

# Authenicate
Login-AzureRmAccount -ServicePrincipal -Tenant  "72f988bf-86f1-41af-91ab-2d7cd011db47" -Credential (Get-Credential -Message "Password" -UserName "74824f88-020e-446b-ba3e-35f75f376987" )
Select-AzureRmSubscription  -SubscriptionName "Demos"

# Start start build server ready for later...
Start-AzureRMVM -Name VSTSBuild -ResourceGroupName "DevOps-Demos" 

Get-AzureRmResourceGroup | Where-Object { $_.Name -match "DevOpsDemo-InfraToAzure*" }  | Get-AzureRmVM | Start-AzureRMVM 

# Retrieve List of Images
#(Get-AzureRmVMImagePublisher -Location "East US" | Get-AzureRmVMImageOffer | Get-AzureRmVMImageSku).Count # 10/3: 1008
# Get-AzureRmVMImagePublisher -Location "West Europe" | Get-AzureRmVMImageOffer | Get-AzureRmVMImageSku | ogv 
Start-Process powershell.exe  -Argument '-command "Login-AzureRmAccount -ServicePrincipal -Tenant  """72f988bf-86f1-41af-91ab-2d7cd011db47""" -Credential (Get-Credential -Message """Password""" -UserName """74824f88-020e-446b-ba3e-35f75f376987"""); Get-AzureRmVMImagePublisher -Location """West Europe""" | Get-AzureRmVMImageOffer | Get-AzureRmVMImageSku | ogv ; read-host "press enter"' 


# open inPrivate Session and check LB
Start-Process "http://techugipconfigdemo.westeurope.cloudapp.azure.com/"

#  Open  VS
Start-Process "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv" -ArgumentList  "$($solutionPath)Infrastructure.sln"

#endregion

#region Infrastructure As Code

#  Open Empty Template in VS
Start-Process "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv" -ArgumentList  "$($solutionPath)Templates\empty.json"

# Show images!


# Create new Resource Group
$ResourceGroupName = "DevOpsDemo1" 
$Region = "West Europe"
New-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName    -Location $Region 

# deploy template

$cred = Get-Credential -Message "Enter Password:" -UserName "adminmarcus"

$param = @{

   "WinOpsVMName"="vm1";
    "WinOpsVMAdminUserName" = $cred.UserName
    "WinOpsVMWindowsOSVersion" = "2016-Nano-Server-Technical-Preview"
    "WinOpsVMAdminPassword" = $cred.Password
}



# see progress in portal
Start-Process "https://portal.azure.com/?feature.customportal=false#asset/HubsExtension/ResourceGroups/subscriptions/802df257-6032-4b50-884c-55cb9f074928/resourceGroups/$ResourceGroupName"

# Add temlate via Portal
Start-Process "https://portal.azure.com/?feature.customportal=false#create/Microsoft.Template"

# GitHub & visualise
Start-Process "https://github.com/Azure/azure-quickstart-templates"


# Start deployment
$depInfra = New-AzureRmResourceGroupDeployment `
        -TemplateFile "$($solutionPath)Templates\simplevm.json"  `
        -ResourceGroupName $ResourceGroupName  `
        -TemplateParameterObject $param



#endregion

#region  Configuration Management

#  Open  Template in VS
Start-Process "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv" -ArgumentList  "$($solutionPath)Templates\infrastructure.json"

psedit  "$($solutionPath)DSC\WinVMconfiguration.ps1"
psedit  "$($solutionPath)DSC\LinuxVMconfiguration.ps1"

# view DSC resources in gallery
Start-Process "https://www.powershellgallery.com/packages"


# DO NOT RUN, already done.

$ResourceGroupName = "DevOpsConfigDemo" 
$Region = "West Europe"
# unique string to prevent duplicate storage account names
$deploymentID = (-join ([char[]](65..90+97..122)*100 | Get-Random -Count 8)).ToLower()

# Create new Resource Group
New-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName   -Location $Region

# Create Storage Account for artifacts
$stor = New-AzureRmStorageAccount `
       -ResourceGroupName $ResourceGroupName `
       -Name $deploymentID `
       -Type Standard_LRS `
       -Location $Region


Azure.Storage\New-AzureStorageContainer -Container "artifacts" -Context $stor.Context

ls -File "$($solutionPath)DSC\" -Recurse `
    | Azure.Storage\Set-AzureStorageBlobContent -Container  "artifacts"   -Context $stor.Context -Force 

# Get SAS token for container, valid for a  day
$SASToken = New-AzureStorageContainerSASToken `
    -Name "artifacts"`
    -Permission r  `
    -Context $stor.Context `
    -ExpiryTime (Get-Date).AddDays(1)

# create automation account
$automationAccount = New-AzureRMAutomationAccount `
    -ResourceGroupName $ResourceGroupName `
   -Location $Region `
  -Name "Automation$deploymentID"

# retrieve the automation account registration info
$automationRegInfo = Get-AzureRmAutomationRegistrationInfo `
     -AutomationAccountName $automationAccount.AutomationAccountName -ResourceGroupName $ResourceGroupName


#import modules required by configurations


[System.Collections.ArrayList]$jobs =  @()

foreach($module in Get-ChildItem -Path "$($solutionPath)DSC\Modules" -Filter "*.zip"){


 $job =  New-AzureRmAutomationModule `
    -Name $module.Name.Replace(".zip","") `
    -ResourceGroupName   $ResourceGroupName `
    -AutomationAccountName $automationAccount.AutomationAccountName `
    -ContentLink "$($stor.PrimaryEndpoints.Blob.AbsoluteUri)artifacts/Modules/$($module.Name)$SASToken"
      $jobs.add($job) 

 }

# wait for all modules to be provisioned
 foreach($job in $jobs){

    while(($job | Get-AzureRmAutomationModule).ProvisioningState  -ne "Succeeded"){
		sleep 5
	}

 }

[System.Collections.ArrayList]$jobs =  @()

foreach($config in Get-ChildItem -Path "$($solutionPath)DSC\" -Filter "*.ps1"){
# import configuration to be used by the VMs

  Import-AzureRmAutomationDscConfiguration  `
    -ResourceGroupName $ResourceGroupName  -AutomationAccountName $automationAccount.AutomationAccountName `
    -SourcePath $config.FullName  `
    -Published -Force

   # Begin compilation of the configuration

$job = Start-AzureRmAutomationDscCompilationJob `
    -ResourceGroupName $ResourceGroupName  -AutomationAccountName $automationAccount.AutomationAccountName `
    -ConfigurationName $config.Name.Replace(".ps1","")
  $jobs.add($job)  
 }

  # Wait until all configurations have compiled
 foreach($job in $jobs){

 while(($job | Get-AzureRmAutomationDscCompilationJob).Status -ne "Completed"){
	sleep 5
 }

 }

 # deploy template

$cred = New-Object System.Management.Automation.PSCredential( "adminmarcus",(ConvertTo-SecureString "Password7Infra" -AsPlainText -force))

$param = @{
      
    "AdminUsername"=$cred.UserName
    "AdminPassword"= $cred.Password
    "DeploymentID"= $deploymentID
    "AutomationRegistrationURL" = $automationRegInfo.Endpoint
    "AutomationRegistrationKey" = $automationRegInfo.PrimaryKey
    "ArtifactsSASToken" = $SASToken.ToString()
    "timestamp" = (Get-Date).ToString()
}


$depInfra = New-AzureRmResourceGroupDeployment `
    -TemplateFile "$($solutionPath)Templates\infrastructure.json"  `
    -ResourceGroupName $ResourceGroupName  `
    -TemplateParameterObject $param


 # Link linux config
$node = Get-AzureRmAutomationDscNode -AutomationAccountName $automationAccount.AutomationAccountName -Name "linuxvm1" -ResourceGroupName $ResourceGroupName
Set-AzureRmAutomationDscNode -AutomationAccountName $automationAccount.AutomationAccountName -Id $node.Id -NodeConfigurationName "LinuxVMConfiguration.localhost" -ResourceGroupName $ResourceGroupName -Force


# open: create in in private session
Start-Process "http://techugipconfigdemo.westeurope.cloudapp.azure.com/"

#endregion

#region ReleaseManagement


Start-Process "https://marcusrobinson.visualstudio.com/DefaultCollection/InstrastructureToAzure/_apps/hub/ms.vss-releaseManagement-web.hub-explorer?definitionId=1&_a=environments-editor"

Start-Process "https://marketplace.visualstudio.com/vss/Build and release?sortBy=Downloads"


#endregion

#region clean up


 ####   Get-AzureRmResourceGroup | Where-Object { $_.ResourceGroupName -like "WinOps*"} | Remove-AzureRmResourceGroup -force

#endregion