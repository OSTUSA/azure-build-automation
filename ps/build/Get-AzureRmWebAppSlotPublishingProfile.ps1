param (
	[Parameter(Mandatory=$true)][string]$tenantId,
	[Parameter(Mandatory=$true)][string]$applicationId,
    [Parameter(Mandatory=$true)][string]$applicationKey,
    [Parameter(Mandatory=$true)][string]$resourceGroup,
    [Parameter(Mandatory=$true)][string]$application,
    [Parameter(Mandatory=$true)][string]$slot
)

trap
{
    Write-Error $_
    exit 1
}

<# SIGN IN WITH SERVICE PRINCIPAL #>
Write-Host "Adding azure service principal to powershell context..."
$SecurePassword = $applicationKey | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $applicationId, $SecurePassword
Add-AzureRmAccount -Credential $cred -Tenant $tenantId -ServicePrincipal

Write-Host "Finding application slot..."
$applicationSlots = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroup -Name $application
$siteName = $application + "(" + $slot + ")"
$tempSlot = $null
foreach($applicationSlot in $applicationSlots)
{
    if ($applicationSlot.SiteName -eq $siteName)
    {
        Write-Host "Found application slot."				
        $tempSlot = $applicationSlot
        break
    }
}

if ($tempSlot -eq $null)
{
    Write-Host "Creating application slot..."
    $tempSlot = New-AzureRmWebAppSlot -ResourceGroupName $resourceGroup -Name $application -Slot $slot
    Write-Host "Created application slot."			
}

Get-AzureRmWebAppSlotPublishingProfile -ResourceGroupName $resourceGroup -Name $application -Slot $slot -Format WebDeploy -OutputFile "$application.publishsettings"