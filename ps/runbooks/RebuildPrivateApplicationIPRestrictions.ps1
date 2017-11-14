param (
    [Parameter(Mandatory=$true)][string]$resourceGroupName,
    [Parameter(Mandatory=$true)][bool]$overwriteExistingRules,
    [Parameter(Mandatory=$true)][string[]]$privateApplications
    )
    
    <# SPECIFY RUNBOOK CONNECTION NAME FOR YOUR IMPLEMENTATION #>
    $runbookConnectionName = ""

    <# SIGN IN WITH SERVICE PRINCIPAL #>
    $conn = Get-AutomationConnection -Name $runbookConnectionName 
    Add-AzureRMAccount -ServicePrincipal -Tenant $conn.TenantID -ApplicationId $conn.ApplicationID -CertificateThumbprint $conn.CertificateThumbprint
    Select-AzureRmSubscription  -SubscriptionId $conn.SubscriptionId
    
    <# WHITELIST LOCAL NETWORKS BY DEFAULT FOR PRIVATE APPLICATIONS #>
    #local networks
    $local10 = @{"ipAddress"="10.0.0.0";"subnetMask"="255.0.0.0"}
    $local172 = @{"ipAddress"="172.0.0.0";"subnetMask"="255.0.0.0"}
    $local192 = @{"ipAddress"="192.0.0.0";"subnetMask"="255.0.0.0"}
    
    $whitelistedIPs= @($local10, $local172, $local192)
    $sites = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Web/sites -IsCollection -ApiVersion 2016-08-01
    
    <# GET PUBLIC IPs FROM ALL APPLICATIONS IN RESOURCE GROUP #>
    foreach ($site in $sites)
    {
        $publicResource = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Web/sites -ResourceName $site.ResourceName -ApiVersion 2016-08-01
        $publicIPs = $publicResource.Properties.outboundIpAddresses -Split ","
        
        foreach($publicIP in $publicIPs)
        {
            $match = $whitelistedIPs.Where({$_.ipAddress -eq $publicIP -and $_.subnetMask -eq "255.255.255.255"})
            if ($match.Count -eq 0)
            {
                $whitelistIP = @{"ipAddress"=$publicIP;"subnetMask"="255.255.255.255"}
                $whitelistedIPs+= $whitelistIP
            }
        }  
    }
    
    <# GRANT ACCESS TO WHITELISTED IPs IN PRIVATE APPS #>
    foreach ($privateApp in $privateApplications)
    {
        $privateResource = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Web/sites/config -ResourceName $privateApp -ApiVersion 2016-08-01
        $properties = $privateResource.Properties
        $properties.ipSecurityRestrictions = @()
    
        if (($properties.ipSecurityRestrictions -eq $null -and $whitelistedIPs.Count -gt 0) -or $overwriteExistingRules)
        {
            $properties.ipSecurityRestrictions = @()
        }

        $currentWhiteListedIPs = $properties.ipSecurityRestrictions
    
        foreach ($ip in $whitelistedIPs)
        {
            $match = $currentWhiteListedIPs.Where({$_.ipAddress -eq $ip.ipAddress -and $_.subnetMask -eq $ip.subnetMask})
    
            if ($match.Count -eq 0)
            {
                $restriction = @{"ipAddress"=$ip.ipAddress;"subnetMask"=$ip.subnetMask}
                $properties.ipSecurityRestrictions+= $restriction
            }
        }
    
        Set-AzureRmResource -ResourceGroupName  $resourceGroupName -ResourceType Microsoft.Web/sites/config -ResourceName $privateApp/web -ApiVersion 2016-08-01 -PropertyObject $properties -Force
    }