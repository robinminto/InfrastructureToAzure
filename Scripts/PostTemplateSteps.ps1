Param
    (
        [Parameter(Mandatory=$true)]
        $ResourceGroupName,


        [Parameter(Mandatory=$true)]
        $Region
)

# Assign config to Linux VM
#$node = Get-AzureRmAutomationDscNode -AutomationAccountName "Automation$ResourceGroupName" -Name "linuxvm1" -ResourceGroupName $ResourceGroupName
#Set-AzureRmAutomationDscNode -AutomationAccountName "Automation$ResourceGroupName" -Id $node.Id -NodeConfigurationName "LinuxVMConfiguration.localhost" -ResourceGroupName $ResourceGroupName -Force

