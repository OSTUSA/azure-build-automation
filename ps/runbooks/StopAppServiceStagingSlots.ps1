workflow Stop-AzureRmStagingSlots
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

    <# GET SLOT IF IT EXISTS, OR CREATE IT #>		
    [string[]] $slots = @()
    foreach($applicationName in $applicationNames)
    {
        (InlineScript { Write-Host "Getting application slots to stop..." })
        $siteName = $applicationName + "(" + $slotName + ")"
        $applicationSlots = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroupName -Name $applicationName 
        $slot = $null
        foreach($applicationSlot in $applicationSlots)
        {
            if ($applicationSlot.SiteName -eq $siteName)
            {
                (InlineScript { Write-Host "Found application slot."})					
                $slot = $applicationSlot
            }
        }
        if ($slot -eq $null)
        {
            (InlineScript { Write-Host "Creating application slot..." })				
            $slot = New-AzureRmWebAppSlot -ResourceGroupName $resourceGroupName -Name $applicationName -Slot $slotName -SourceWebApp $applicationName
            (InlineScript { Write-Host "Created application slot." })				
        }

        $slots += $slot
    }

	<# STOP ALL SLOTS IN PARALLEL #>	
    (InlineScript { Write-Host "Stopping slots..." })
    foreach -parallel ($applicationName in $applicationNames)
    {
        Stop-AzureRmWebAppSlot -ResourceGroupName $resourceGroupName -Name $applicationName -Slot $slotName
    }
}