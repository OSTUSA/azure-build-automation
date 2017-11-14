param (
	[Parameter(Mandatory=$true)][string]$tenantId,
	[Parameter(Mandatory=$true)][string]$applicationId,
    [Parameter(Mandatory=$true)][string]$applicationKey,
	[Parameter(Mandatory=$true)][string]$resourceGroup,
    [Parameter(Mandatory=$true)][string]$automationAccountName,
    [Parameter(Mandatory=$true)][string]$runbookName,
	[Parameter(Mandatory=$true)][System.Collections.IDictionary]$params
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

<# START RUNBOOK #>
Write-Host "Azure service principal added to powershell context."
Write-Host "Starting Runbook $runbookName..."
$job = Start-AzureRmAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    –AutomationAccountName $automationAccountName `
    –Name $runbookName `
    -ErrorAction Stop `
    -Parameters $params 

Write-Host "$runbookName has been started."

<# PING RUNBOOK STATUS UNTIL COMPLETE #>
Write-Host -NoNewLine "Waiting for $runbookName to complete..."
$doLoop = $true
if ($job -ne $null){
    While ($doLoop) {
       Start-Sleep -s 5
       $job = Get-AzureRmAutomationJob -ResourceGroupName $resourceGroup `
       -AutomationAccountName $automationAccountName -Id $job.JobId
       $status = $job.Status
       $doLoop = (($status -ne "Completed") -and ($status -ne "Failed") -and ($status -ne "Suspended") -and ($status -ne "Stopped"))
       Write-Host -NoNewLine .
    }
    Write-Host
}

<# RETURN RUNBOOK STATUS #>
if ($status -ne "Completed")
{
    throw "Failed to execute runbook successfully - $status"
}
else
{
    Write-Host "$runbookName completed successfully - $status"
    exit 0
}