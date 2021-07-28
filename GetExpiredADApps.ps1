################################################
# Pre-reqs:
#  1. Create an App Registration in the target tenant, e.g. with name of GetExpiredADApps, with API permissions of:
#        Microsoft Graph - Application.Read.All - Application (type)
#     If deleting is also to be accommodated:
#        Microsoft Graph - Application.ReadWrite.All - Application (type)
#  2. Grant admin consent for your domain for these permissions
#  3. Create a certificate (can be self-signed) and upload to app registration
#  4. Ensure certificate is in the certificate store of the account that will run the script
#  5. Update the $TenantID, $ADAppID and $ADAppCertThumbprint variables, and any of the other variables that may need to be changed
#  6. If running locally, run as administrator
################################################

param(
    [Parameter(Mandatory=$true)][String]$TenantID,
    [Parameter(Mandatory=$true)][String]$ADAppID,
    [Parameter(Mandatory=$true)][String]$ADAppCertThumbprint,
    [Parameter(Mandatory=$true)][Int]$ThresholdDays
  )

$ErrorActionPreference = 'Stop'
Import-Module AzureAD

$IncludeExpired = $true

## Function to test if application should be added to the list
function CheckAppDates($app, $credential, $secretOrCertificate, $endDate)
{
    $daysTillExpiry = ($endDate - $now).Days

    # Add expired credentials to the app list, if required to do so
    if ($IncludeExpired -and $daysTillExpiry -le 0) {
        AddToAppList -app $app -credential $credential -secretOrCertificate $secretOrCertificate -daysTillExpiry $daysTillExpiry
    }
    # Add apps with credentials that will expire on or before the specified threshold
    elseif (($daysTillExpiry -gt 0) -and ($daysTillExpiry -le $ThresholdDays))
    {
        AddToAppList -app $app -credential $credential -secretOrCertificate $secretOrCertificate -daysTillExpiry $daysTillExpiry
    }
}

### Function to add application to the list
function AddToAppList($app, $credential, $secretOrCertificate, $daysTillExpiry)
{
    $AppName = $app.DisplayName
    $ObjectID = $app.objectid
    $ApplicationID = $app.AppId
    $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
    $Username = $Owner.UserPrincipalName -join ","
    $OwnerID = $Owner.ObjectID -join ","
    if (($owner.UserPrincipalName -eq $Null) -or ($Owner.DisplayName -eq $null)) {
        $Username = ""
    }

    $Log = New-Object System.Object

    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
    $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplicationID
    $Log | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
    $Log | Add-Member -MemberType NoteProperty -Name "Type" -Value $secretOrCertificate
    $Log | Add-Member -MemberType NoteProperty -Name "KeyID" -Value $credential.KeyId
    $Log | Add-Member -MemberType NoteProperty -Name "Start Date" -Value $credential.StartDate
    $Log | Add-Member -MemberType NoteProperty -Name "End Date" -Value $credential.EndDate
    $Log | Add-Member -MemberType NoteProperty -Name "Days Till Expiry" -Value $daysTillExpiry
    $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
    $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

    $global:ExpiryAppList += $Log

}

######################################################
# Start of main controlling process
######################################################

#region - Intialise variables
$global:ExpiryAppList = @()
$now = (Get-Date).Date.AddHours(-1 * ((Get-TimeZone).BaseUtcOffset.Hours)) # take the beginning of today, and adjust for the current timezone

# Login to Azure 
$context = Connect-AzureAD -TenantId $TenantID -CertificateThumbprint $ADAppCertThumbprint -ApplicationId $ADAppID

# Get all Azure AD Applications - for large lists this could take long
$Applications = Get-AzureADApplication -all $true
Write-Host ("Total of " + $Applications.Count + " applications found. Reviewing all for expired secrets and certificates")

# Loop over each application, get the secrets and certs, and for each secret / cert check if we need to add the app to the list
foreach ($app in $Applications) {
    $ObjectID = $app.objectid
    $AppCreds = Get-AzureADApplication -ObjectId $ObjectID | select PasswordCredentials, KeyCredentials
    $secret = $AppCreds.PasswordCredentials
    $cert = $AppCreds.KeyCredentials

    foreach ($s in $secret) {
        $secretCount ++;
        $EndDate = $s.EndDate
        CheckAppDates -app $app -credential $s -secretOrCertificate 'Secret' -endDate $EndDate
    }

    foreach ($c in $cert) {
        $certCount ++;
        $EndDate = $c.EndDate
        CheckAppDates -app $app -credential $c -secretOrCertificate 'Certificate' -endDate $EndDate
    }
}

Write-Host ($global:ExpiryAppList.Count.ToString() + " expired or soon to be expired secrets and/or certificates found")
