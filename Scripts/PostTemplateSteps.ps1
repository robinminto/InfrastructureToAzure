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

# Assign config to Linux VM
$node = Get-AzureRmAutomationDscNode -AutomationAccountName "Automation$DeploymentID" -Name "linuxvm1" -ResourceGroupName $ResourceGroupName
Set-AzureRmAutomationDscNode -AutomationAccountName "Automation$DeploymentID" -Id $node.Id -NodeConfigurationName "LinuxVMConfiguration.localhost" -ResourceGroupName $ResourceGroupName -Force

