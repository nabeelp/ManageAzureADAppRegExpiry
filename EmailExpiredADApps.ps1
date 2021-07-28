param(
    [Parameter(Mandatory=$true)][String]$TenantID,
    [Parameter(Mandatory=$true)][String]$ADAppID,
    [Parameter(Mandatory=$true)][String]$ADAppCertThumbprint,
    [Parameter(Mandatory=$true)][String]$SMTPPass,
    [Parameter(Mandatory=$true)][String]$SMTPServer,
    [Parameter(Mandatory=$true)][String]$SMTPPort,
    [Parameter(Mandatory=$true, HelpMessage='Email address to use where no app owner exists, and will be used for fromEmail and ccEmail if those are not supplied')][String]$defaultEmail,
    [Parameter(Mandatory=$false)][String]$fromEmail,
    [Parameter(Mandatory=$false)][String]$ccEmail
)

$ErrorActionPreference = 'Stop'

# Number of days for the threshold of colors to use in email body
$InformDays = 30
$WarnDays = 15
$AlertDays = 5

# Colors to use in email body for the different threshold levels
$InformDaysColor = 'Yellow'
$WarnDaysColor = 'Orange'
$AlertDaysColor = 'Red'

# Set to $false if you don't want to actually send the mail ... this will output the mail to console
$sendMail = $true

# Email template
$emailBodyTemplate = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta content="en-us" http-equiv="Content-Language" />
<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
<style>
  body {
    font-family: "Arial";
    font-size: 8pt;
    color: #4C607B;
    }
  th, td { 
    border: 1px solid #e57300;
    border-collapse: collapse;
    padding: 5px;
    }
  th {
    font-size: 1.2em;
    text-align: left;
    background-color: #003366;
    color: #ffffff;
    }
  td {
    color: #000000;
    }
</style>
</head>
<body>
<p>
    <table>
        <tr>
            <th>Application Name</th>
            <th>Application Id</th>
            <th>Type</th>
            <th>Expiration Date</th>
            <th>Days Till Expiry</th>
        </tr>
        OUTPUT_TABLE_ROWS
    </table>
</p>
</body>
</html>
"@

# Call Powershell to get list of expired and soon to be expired apps and put them in the global:ExpiryAppList variable
.\GetExpiredADApps.ps1 -TenantID $TenantID -ADAppID $ADAppID -ADAppCertThumbprint $ADAppCertThumbprint -ThresholdDays $InformDays

# Use the list of applications to generate notifications to each owner, where available
if ($global:ExpiryAppList.Count -gt 0)
{
    # set ccEmail and/or fromEmail if required
    if ($fromEmail.Length -eq 0) { $fromEmail = $defaultEmail }
    if ($ccEmail.Length -eq 0) { $ccEmail = $defaultEmail }

    # create email credentials
    $securePassword = ConvertTo-SecureString $SMTPPass -AsPlainText -Force
    $emailcred = New-Object System.Management.Automation.PSCredential ($fromEmail, $securePassword)  

    # run over the list of apps and populate
    $appList = $global:ExpiryAppList | sort Owner, 'End Date'
    $outputRows = ''
    $appCount = 0
    for ($i = 0 ; $i -lt $appList.Count ; $i++)
    {
        $appCount++;
        $thisApp = $appList[$i]

        # determine the severity, based on days till expiry, assuming red (for alert and already expired)
        if ($thisApp.'Days Till Expiry' -le $AlertDays) { $color = $AlertDaysColor }
        elseif ($thisApp.'Days Till Expiry' -le $WarnDays) { $color = $WarnDaysColor }
        else { $color = $InformDaysColor }

        # add a row to the table
        $outputRows = $outputRows + (
            '<tr style="background-color: ' + $color + '">
                <td>' + $thisApp.ApplicationName + '</td>
                <td>' + $thisApp.ApplicationId + '</td>
                <td>' + $thisApp.Type + '</td>
                <td>' + $thisApp.'End Date' + '</td>
                <td style="text-align:right">' + $thisApp.'Days Till Expiry' + '</td>
            </tr>')

        # send mail, if the next app is for a different owner or if we reached the end of the list
        if (($i -eq $appList.Count) -or ($thisApp.Owner -ne $appList[$i + 1].Owner))
        {
            # get the owner's email address, and handle 
            $subject = "Azure AD Applications Expiring"
            if ($thisApp.Owner -eq "") {
                $toEmail = $defaultEmail
                $subject += " - Apps with no Owner"
            } else {
                $toEmail = $thisApp.Owner
            }
            $emailBody = $emailBodyTemplate.Replace("OUTPUT_TABLE_ROWS",$outputRows)

            # send the mail
            if ($sendMail)
            {
                Write-Host ("Sending email to " + $toEmail + " with a list of " + $appCount + " expired or soon to be expired secrets and/or certificates")
                # TODO: Ensure we use SSL
                # Send-MailMessage -To $toEmail.Split(',') -From $fromEmail -Cc $ccEmail -Subject "Azure AD Applications Expiring" -BodyAsHtml $emailBody -SmtpServer $SMTPServer -Port $SMTPPort -Credential $emailcred -UseSsl 
                Send-MailMessage -To $toEmail.Split(',') -From $fromEmail -Cc $ccEmail -Subject $subject -BodyAsHtml $emailBody -SmtpServer $SMTPServer -Port $SMTPPort -Credential $emailcred #-UseSsl 
            }
            else
            {
                Write-Output ("To: " + $toEmail + ", HTML: " + $emailBody)
            }

            # reset the output table
            $outputRows = ''
            $appCount = 0
        }
    }
}