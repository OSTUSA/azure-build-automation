workflow DeleteAppServiceSlots
{
    param (
    [Parameter(Mandatory=$true)][string]$resourceGroupName,
    [Parameter(Mandatory=$true)][string[]]$applicationNames, 
    [Parameter(Mandatory=$true)][string]$slotName
	)

	<# SPECIFY RUNBOOK CONNECTION NAME FOR YOUR IMPLEMENTATION #>
	$runbookConnectionName = ""

    $conn = Get-AutomationConnection -Name $runbookConnectionName
    Add-AzureRMAccount -ServicePrincipal -Tenant $conn.TenantID -ApplicationId $conn.ApplicationID -CertificateThumbprint $conn.CertificateThumbprint
    Select-AzureRmSubscription  -SubscriptionId $conn.SubscriptionId

    <# FIND APPLICATIONS THAT HAVE THE SLOT SPECIFIED#>		
    [string[]] $applicationWorkingList = @()
    foreach($applicationName in $applicationNames)
    {
        (InlineScript { Write-Host "Getting application slots to delete..." })
        $siteName = $applicationName + "(" + $slotName + ")"
        $applicationSlots = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroupName -Name $applicationName

        foreach($applicationSlot in $applicationSlots)
        {
            if ($applicationSlot.SiteName -eq $siteName)
            {				
                $applicationWorkingList += $applicationName
            }
        }        
    }

	<# DELETE ALL SLOTS IN PARALLEL #>	
    (InlineScript { Write-Host "Deleting slots..." })
    foreach -parallel ($applicationName in $applicationWorkingList)
    {
        Remove-AzureRmWebAppSlot -ResourceGroupName $resourceGroupName -Name $applicationName -Slot $slotName
    }
}