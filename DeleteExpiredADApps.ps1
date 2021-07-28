param(
    [Parameter(Mandatory=$true)][Int]$ExpiredDaysThreshold,
    [Parameter(Mandatory=$true)][String]$TenantID,
    [Parameter(Mandatory=$true)][String]$ADAppID,
    [Parameter(Mandatory=$true)][String]$ADAppCertThumbprint,
    [Parameter(Mandatory=$true)][Boolean]$PerformDelete
  )

$ErrorActionPreference = 'Stop'
Import-Module AzureAD

# Call Powershell to get list of expired apps and put them in the global:ExpiryAppList variable
.\GetExpiredADApps.ps1 -TenantID $TenantID -ADAppID $ADAppID -ADAppCertThumbprint $ADAppCertThumbprint -ThresholdDays 0

# Login to Azure 
$context = Connect-AzureAD -TenantId $TenantID -CertificateThumbprint $ADAppCertThumbprint -ApplicationId $ADAppID

# Use the list of applications to delete any where the expired details are more than x days expired
if ($global:ExpiryAppList.Count -gt 0)
{
    # run over the list of apps and delete
    $appList = $global:ExpiryAppList
    $appCount = 0
    for ($i = 0 ; $i -lt $appList.Count ; $i++)
    {
        $thisApp = $appList[$i]

        if ($thisApp.'Days Till Expiry' -le ($ExpiredDaysThreshold * -1)) {
            # prepare the delete command
            if ($thisApp.Type -eq 'Secret') {
                $command = 'Remove-AzureADApplicationPasswordCredential -ObjectId ' + $thisApp.ObjectID + ' -KeyId ' + $thisApp.KeyID
            } else {
                $command = 'Remove-AzureADApplicationKeyCredential -ObjectId ' + $thisApp.ObjectID + ' -KeyId ' + $thisApp.KeyID
            }

            # execute or output the command
            if ($PerformDelete) {
                Invoke-Expression $command
            } else {
                Write-Host $command
            }

            $appCount++
        }
    }
}

Write-Host ($appCount.ToString() + " expired secrets and/or certificates deleted")