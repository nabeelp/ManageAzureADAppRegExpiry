# ManageAzureADAppRegExpiry
## Introduction
The purpose of this repo is to provide a set of utilities (currently PowerShell, but could become more) that will aid in the identification and management of app registration secrets and certificates that have expired or are about to expire.  At present, the utilities cater for:
1. Generating a list of app registration certificates or secrets that have already expired, or are about to expire, within a specified number of days: `ThresholdDays`
2. Emailing the above list in a tabular format to the owners of the app registrations, if the owners exist, with color coding of the rows, based on whether the certificate/secret has expired, or is soon to expire.
3. Deleting the already expired certificates/secrets from the generated list, where the number of days since expiry is above a specified number of days: `ExpiredDaysThreshold`

## Running the scripts
To run any of the scripts, you will need to:
1. Create an App Registration in the target tenant, e.g. with name of ManageExpiredADAppCredentials, with API permissions of:

    API | Permission| Type
    --|--|--
    Azure Active Directory Graph | Application.Read.All | Application

1. To perform deletions the application will require the following API permission, either together with the above or in place of it:

    API|Permission|Type
    --|--|--
    Azure Active Directory Graph | Application.ReadWrite.All | Application

2. Grant admin consent for your domain for these permissions
3. Create a certificate (can be self-signed) and upload to app registration
4. Ensure certificate is in the certificate store of the account that will run the script
5. Record the values that will be used for TenantID, ADAppID and ADAppCertThumbprint parameters of the PowerShell scripts
6. If running locally, run in an administrator session of Powershell

### Executing GetExpiredADApps
While this script is designed to be used by the other scripts, it can also be run in isolation.  To execute, use the following command:

```powershell
.\GetExpiredADApps.ps1 -TenantID $TenantID -ADAppID $ADAppID -ADAppCertThumbprint $ADAppCertThumbprint -ThresholdDays 30
```

The result of executing this will be to populate the `$global:ExpiryAppList` variable with the secrets and certificates that have expired or will expired within 30 days.

### Executing EmailExpiredADApps
This script will execute the GetExpiredADApps script, and will then use the resultant data to formulate and send emails to the owners of the applications, informing them of the expired and soon to be expired secrets and certificates.

```powershell
.\EmailExpiredADApps.ps1 -TenantID $TenantID -ADAppID $ADAppID -ADAppCertThumbprint $ADAppCertThumbprint -defaultEmail 'user@domain.com' -SMTPPass 'mypassword' -SMTPServer 'smtpserver.com' -SMTPPort 587
```

Once executed, this script will generate an email per unique owner (or set of owners) for an application, tabulating the expired or soone to be expired secrets and certificates. The threshold values and colors can be adjusted by chaging the paramters within the script.

### Executing DeleteExpiredADApps
This script will execute the GetExpiredADApps script, and will then use the resultant data to identify and delete secrets and certificates that expired more than 15 days ago.

```powershell
.\DeleteExpiredADApps.ps1 -TenantID $TenantID -ADAppID $ADAppID -ADAppCertThumbprint $ADAppCertThumbprint -ExpiredDaysThreshold 15 -PerformDelete $true
```

If the `-PerformDelete` parameter is set to `$true`, this script will delete those secrets and certificates that expired more than the number of days provided as the value for the `ExpiredDaysThreshold` parameter.  If the `-PerformDelete` parameter is set to `$false`, the script will output the command that would have been executed to perform the delete, allowing you to review what will be done before executing again to perform the actual delete.

## Notes
1. Currently only works in PowerShell and not PowerShell Core, beacuse of the use of the AzureAD module
2. Requires the permissions for the legacy Azure Active Directory Graph APIs. 
