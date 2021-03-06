﻿$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 
Set-StrictMode -Version 2.0
$verbosePreference = 'SilentlyContinue'
$errorActionPreference = 'Stop'
. (Join-Path $PSScriptRootV2 '..\Common\HelperFunctions.ps1')

Clear
Log -kind Emphasis -OnlyInfo "Welcome to the Virtual Machine Initialize script."
Log -kind Info -OnlyInfo ""
Log -kind Info -OnlyInfo "This script will help you setup your Microsoft Dynamics NAV DEMO Environment on Azure."
Log -kind Info -OnlyInfo "The script will help you:"
Log -kind Info -OnlyInfo "- Select what country version of NAV you want to use."
Log -kind Info -OnlyInfo "- Change NAV to Username/Password authentication"
Log -kind Info -OnlyInfo "- Setup SSL with trusted certificate or self signed certificate."
Log -kind Info -OnlyInfo "- Welcome to the Virtual Machine Initialize script."
Log -kind Info -OnlyInfo "- Alter firewall rules to allow public access."
Log -kind Info -OnlyInfo "- Setup Landing page for easy access to all resources."
Log -kind Info -OnlyInfo "- Change Default Role Center to Business Manager (9022)."
Log -kind Info -OnlyInfo ""

Log "Read Settings"
$HardcodeFile = (Join-Path $PSScriptRootV2 'HardcodeInput.ps1')
if (Test-Path -Path $HardcodeFile) {
    . $HardcodeFile
}
$DVDfolder = (Get-ChildItem -Path "C:\NAVDVD" -Directory | where-object { Test-Path -Path (Join-Path $_.FullName "WindowsPowerShellScripts") -PathType Container } | Select-Object -First 1).FullName
$NavVersion = (Get-ChildItem -Path "c:\program files\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).Name
$DatabaseFolder = Join-Path (Get-ChildItem -Path "$DVDFolder\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "Database"
$DatabaseName = (Get-ChildItem -Path $DatabaseFolder -Filter "*.bak" -File).BaseName

Log "NAV Version: $NavVersion"
Log "Database Name: [$DatabaseName]"
Log "Import Modules"

Push-Location
Import-module SQLPS -DisableNameChecking
Pop-Location
. (Join-Path $PSScriptRootV2 'HelperFunctions.ps1')
. ("c:\program files\Microsoft Dynamics NAV\$NavVersion\Service\NavAdminTool.ps1") | Out-Null
Import-Module (Join-Path $DVDFolder "WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1") | Out-Null
. (Join-Path $PSScriptRootV2 'New-SelfSignedCertificateEx.ps1')

$CustomSettingsConfigFile = "c:\program files\Microsoft Dynamics NAV\$NavVersion\Service\CustomSettings.config"
$config = [xml](Get-Content $CustomSettingsConfigFile)
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value

Log "Server Instance: $ServerInstance"

$regionCodes = @{ 
 "AT" = "de-AT";
 "AU" = "en-AU"; 
 "BE" = "nl-BE";
 "CH" = "de-CH";
 "CZ" = "cs-CZ";
 "DE" = "de-DE";
 "DK" = "da-DK";
 "ES" = "es-ES";
 "FI" = "fi-FI";
 "FR" = "fr-FR";
 "GB" = "en-GB";
 "IS" = "is-IS";
 "IT" = "it-IT";
 "NA" = "en-US";
 "NL" = "nl-NL";
 "NO" = "nb-NO";
 "NZ" = "en-NZ";
 "RU" = "ru-RU";
 "SE" = "sv-SE";
 "W1" = "en-US";
 "US" = "en-US";
 "MX" = "es-MX";
 "CA" = "en-CA";
 "DECH" = "de-CH";
 "FRBE" = "fr-BE";
 "FRCA" = "fr-CA";
 "FRCH" = "fr-CH";
 "ITCH" = "it-CH";
 "NLBE" = "nl-BE";
}

$languageCodes = @{ 
 "AT" = "3079";
 "AU" = "3081";
 "BE" = "2067";
 "CH" = "2055";
 "CZ" = "1029";
 "DE" = "1031";
 "DK" = "1030";
 "ES" = "1034";
 "FI" = "1035";
 "FR" = "1036";
 "GB" = "2057";
 "IS" = "1039";
 "IT" = "1040";
 "NA" = "1033";
 "NL" = "1043";
 "NO" = "1044";
 "NZ" = "5129";
 "RU" = "1049";
 "SE" = "1053";
 "W1" = "1033";
 "US" = "1033";
 "MX" = "1034";
 "CA" = "1033";
 "DECH" = "1031";
 "FRBE" = "1036";
 "FRCA" = "1036";
 "FRCH" = "1036";
 "ITCH" = "1040";
 "NLBE" = "1043";
}

if (!(Test-Path (Join-Path $PSScriptRootV2 '..\Profiles.ps1'))){

    $LanguageCol = @()
    Get-ChildItem -Path "C:\NAVDVD" -Directory | where-object { Test-Path -Path (Join-Path $_.FullName "WindowsPowerShellScripts") -PathType Container } | % { $LanguageCol += $_.Name }
    $Languages = [string]::Join(', ',$LanguageCol)

    if ($LanguageCol.Contains("W1")) {
        $DefaultLanguage = "W1"
    } else {
        $DefaultLanguage = $LanguageCol[0]
    }
        
    $Language = Get-UserInput -Id Language -Text "Please select NAV Language ($Languages)" -Default $DefaultLanguage
    if (($LanguageCol.Count -eq 1) -or ($Language -eq "W1")) {

        $bakFile = "None"

    } else {

        if (!(Test-Path "C:\NAVDVD\$Language")) {
            throw "Selected language is not available on the VM"
        }

        #Install platform files
        Get-ChildItem "C:\NAVDVD\$Language\Installers" | Where-Object { $_.PSIsContainer } | % {
            Get-ChildItem $_.FullName | Where-Object { $_.PSIsContainer } | % {
                $dir = $_.FullName
                Get-ChildItem (Join-Path $dir "*.msi") | % { 
                    Write-Verbose ("Installing "+$_.FullName)
                    Start-Process -FilePath $_.FullName -WorkingDirectory $dir -ArgumentList "/qn /norestart" -Wait
                }
            }
        }

        $regionCode = $regionCodes[$Language]

        Set-WinSystemLocale $regionCode
        
        $BakFolder = Join-Path (Get-ChildItem -Path "C:\NAVDVD\$Language\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "Database"
        $BakFile = (Get-ChildItem -Path $BakFolder -Filter "*.bak" -File).FullName
    }

    do {
        $bakFile = Get-UserInput -Id RestoreAndUseBakFile -Text "Restore and use Database Bak File From Path/Url (Enter None to avoid restore)" -Default $bakFile
        if ($bakFile.StartsWith("http://") -or $bakFile.StartsWith("https://")) {
            $Folder = "C:\DOWNLOAD"
            New-Item $Folder -itemtype directory -ErrorAction ignore
            $Filename = "$Folder\database.bak"
            try {
                Write-Verbose "Downloading $bakFile to $FileName"
                Invoke-WebRequest $bakFile -OutFile $Filename
                $bakFile = $Filename
            } catch {
                Write-Verbose "Error downloading $bakFile to $FileName"
            }
        }
    } until ($bakFile.StartsWith("http://") -or $bakFile.StartsWith("https://") -or ($bakFile -eq "None") -or (Test-Path -Path $bakFile))

    if ($bakFile -ne "None") {

        Set-NAVServerInstance -ServerInstance $serverInstance -Stop
        Push-Location

        #Install local DB
        Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
        "USE [master]
        alter database [$DatabaseName] set single_user with rollback immediate"
        
        Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
        "USE [master]
        drop database [$DatabaseName]"

        Pop-Location

        New-NAVDatabase -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName $DatabaseName -FilePath $bakFile -DestinationPath "C:\Program Files\Microsoft SQL Server\MSSQL13.NAVDEMO\MSSQL\DATA" -Timeout 0
        Set-NAVServerInstance -ServerInstance $serverInstance -Start

    }

    Copy (Join-Path $PSScriptRootV2 "..\Profiles\$Language.ps1") (Join-Path $PSScriptRootV2 '..\Profiles.ps1')
    . (Join-Path $PSScriptRootV2 '..\Profiles.ps1')

    $languageCode = $languageCodes[$Language]

    Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
    "USE [$DatabaseName]
    UPDATE [dbo].[User Personalization] SET [Language ID]='$languageCode', [Locale ID]='$languageCode', [Company]='$Company';"
    
    C:

} else {
    . (Join-Path $PSScriptRootV2 '..\Profiles.ps1')
}
$languageCode = $languageCodes[$Language]

$vmadmin = $env:USERNAME

$NavAdminUser = Get-UserInput -Id NavAdminUser -Text "NAV administrator username" -Default "admin"
$NavAdminPassword = Get-SecureUserInput -Id NavAdminPassword -Text "NAV administrator Password"

# Write NAV Admin Username and Password to multitenancy HardcodeInput
('$NavAdminUser = "'+$NavAdminUser+'"')         | Add-Content 'C:\DEMO\Multitenancy\HardcodeInput.ps1'
('$NavAdminPassword = "'+$NavAdminPassword+'"') | Add-Content 'C:\DEMO\Multitenancy\HardcodeInput.ps1'

do
{
    $err = $false
    $CloudServiceName = Get-UserInput -Id CloudServiceName -Text "What is the public DNS name of your NAV Server" -Default "$env:COMPUTERNAME.cloudapp.net"
    try
    {
        $myIP = Get-MyIp
        $dnsrecord = Resolve-DnsName $CloudServiceName -ErrorAction SilentlyContinue -Type A
        if (!($dnsrecord) -or ($dnsrecord.Type -ne "A") -or ($dnsrecord.IPAddress -ne $myIP)) {
            Log -kind Warning "$cloudservicename is NOT the public DNS name."
            Log -OnlyInfo "If your VM was created in the classic Portal, the public DNS name is the Cloud Service Name followed by .cloudapp.net"
            Log -OnlyInfo "If your VM was created in the new Portal, the public DNS name can by found under the PublicIP resource."
            $err = $true
        }
    } 
    catch {}
} while ($err)

# Create http directory
$httpWebSiteDirectory = "C:\inetpub\wwwroot\http"
new-item -Path $httpWebSiteDirectory -ItemType Directory -Force | Out-Null

. (Join-Path $PSScriptRootV2 'Certificate.ps1')

# Grant Access to certificate to user running Service Tier (NETWORK SERVICE)
Grant-AccountAccessToCertificatePrivateKey -CertificateThumbprint $thumbprint -ServiceAccountName "NT AUTHORITY\Network Service" | Out-Null

# Add a NavUserPassword User who is SUPER
$user = Get-NAVServerUser $serverInstance | % { if ($_.UserName -eq $NavAdminUser) { $_ } }
if (!$user) {
    New-NAVServerUser $serverInstance -UserName $NavAdminUser -Password (ConvertTo-SecureString -String $NavAdminPassword -AsPlainText -Force) -ChangePasswordAtNextLogOn:$false -LicenseType Full
    New-NAVServerUserPermissionSet $serverInstance -UserName $NavAdminUser -PermissionSetId "SUPER"
}

Log "Changing NAV Server Configuration"
Set-NAVServerConfiguration $serverInstance -KeyName "ServicesCertificateThumbprint" -KeyValue $thumbprint -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "SOAPServicesSSLEnabled" -KeyValue 'true' -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "SOAPServicesEnabled" -KeyValue 'true' -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "ODataServicesSSLEnabled" -KeyValue 'true' -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "ODataServicesEnabled" -KeyValue 'true' -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "PublicODataBaseUrl" -KeyValue ('https://' +$PublicMachineName + ':7048/' + $serverInstance + '/OData/') -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "PublicSOAPBaseUrl" -KeyValue ('https://' + $PublicMachineName + ':7047/' + $serverInstance + '/WS/') -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "PublicWebBaseUrl" -KeyValue ('https://' + $PublicMachineName + '/' + $serverInstance + '/WebClient/') -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "PublicWinBaseUrl" -KeyValue ('DynamicsNAV://' + $PublicMachineName + ':7046/' + $serverInstance + '/') -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "ClientServicesCredentialType" -KeyValue "NavUserPassword" -WarningAction Ignore
Set-NAVServerConfiguration $serverInstance -KeyName "ServicesDefaultCompany" -KeyValue $Company -WarningAction Ignore

Log "Restart NAV Server"
Set-NAVServerInstance -ServerInstance $serverInstance -Restart

Log "Expose NAV Web Services"
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 9170 -ServiceName Profile          -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 21   -ServiceName Customer         -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 26   -ServiceName Vendor           -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 30   -ServiceName Item             -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 42   -ServiceName SalesOrder       -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 1304 -ServiceName MiniSalesInvoice -Published:$true -ErrorAction SilentlyContinue

Log "Add firewall rules"
New-FirewallPortAllowRule -RuleName "HTTP access" -Protocol TCP -Port 80 | Out-Null
New-FirewallPortAllowRule -RuleName "NAV SOAP Services" -Protocol TCP -Port 7047 | Out-Null
New-FirewallPortAllowRule -RuleName "NAV OData Services" -Protocol TCP -Port 7048 | Out-Null
New-FirewallPortAllowRule -RuleName "NAV Web Client SSL" -Protocol TCP -Port 443 | Out-Null

Log "Remove default Web Site"
Remove-DefaultWebSite -ErrorAction SilentlyContinue

Log "Remove Bindings from NAV Web Client"
Get-WebBinding -Name "Microsoft Dynamics NAV 2017 Web Client" | Remove-WebBinding

Log "Add SSL binding to NAV Web Client"
New-SSLWebBinding -Name "Microsoft Dynamics NAV 2017 Web Client" -Thumbprint $thumbprint | Out-Null

Log "Modify App Pool setting for LoadUserProfile"
$appPoolName = "Microsoft Dynamics NAV 2017 Web Client Application Pool"
$appPool = get-item "IIS:\AppPools\$appPoolName"
if ($appPool.State -eq "Started") { $appPool.Stop() }
Set-ItemProperty "IIS:\AppPools\$appPoolName" -name "processModel.loadUserProfile" -Value $false
$appPool = get-item "IIS:\AppPools\$appPoolName"
$appPool.Start()

# Create HTTP site
if (!(Get-Website -Name http)) {
    # Create the web site
    Log "Create http Web Site"
    New-Website -Name http -IPAddress * -Port 80 -PhysicalPath $httpWebSiteDirectory -Force | out-null
}

Log "Copy files to http Web site"
Copy-Item (Join-Path $PSScriptRootV2 'Default.aspx')     "$httpWebSiteDirectory\Default.aspx" 
Copy-Item (Join-Path $PSScriptRootV2 'status.aspx')      "$httpWebSiteDirectory\status.aspx" 
Copy-Item (Join-Path $PSScriptRootV2 'WindowsStore.png') "$httpWebSiteDirectory\WindowsStore.png" 
Copy-Item (Join-Path $PSScriptRootV2 'AppStore.png')     "$httpWebSiteDirectory\AppStore.png" 
Copy-Item (Join-Path $PSScriptRootV2 'GooglePlay.png')   "$httpWebSiteDirectory\GooglePlay.png" 
Copy-Item (Join-Path $PSScriptRootV2 'line.png')         "$httpWebSiteDirectory\line.png" 
Copy-Item (Join-Path $PSScriptRootV2 'Microsoft.png')    "$httpWebSiteDirectory\Microsoft.png" 
Copy-Item (Join-Path $PSScriptRootV2 'web.config')       "$httpWebSiteDirectory\web.config" 

Log "Change Web.config"
$WebConfigFile = "C:\inetpub\wwwroot\$serverInstance\Web.config"
$WebConfig = [xml](Get-Content $WebConfigFile)
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='HelpServer']").value="$PublicMachineName"
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='DnsIdentity']").value=$dnsidentity
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='ClientServicesCredentialType']").value="NavUserPassword"
$WebConfig.Save($WebConfigFile)

Log "Change global ClientUserSettings"
$ClientUserSettingsFile = Join-Path (Get-ChildItem -Path "C:\Users\All Users\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "ClientUserSettings.config"
$ClientUserSettings = [xml](Get-Content $ClientUserSettingsFile)
$ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value= "NavUserPassword"
$ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='HelpServer']").value= "$PublicMachineName"
$ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='DnsIdentity']").value= $dnsidentity
$ClientUserSettings.Save($ClientUserSettingsFile)

if (Test-Path -Path "C:\Users\$vmadmin\AppData\Roaming\Microsoft\Microsoft Dynamics NAV") {
    Log "Change vmadmin ClientUserSettings"
    $ClientUserSettingsFile = Join-Path (Get-ChildItem -Path "C:\Users\$vmadmin\AppData\Roaming\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "ClientUserSettings.config"
    if (Test-Path -Path $ClientUserSettingsFile) {
        $ClientUserSettings = [xml](Get-Content $ClientUserSettingsFile)
        $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value= "NavUserPassword"
        $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='HelpServer']").value= "$PublicMachineName"
        $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='DnsIdentity']").value= $dnsidentity
        $ClientUserSettings.Save($ClientUserSettingsFile)
    }
}

# Set default profile to Business Manager
$AccountingManager = ($profiles.GetEnumerator() | Where-Object { $_.Value -eq "9001" }).Name
$OrderProcessor    = ($profiles.GetEnumerator() | Where-Object { $_.Value -eq "9006" }).Name
$BusinessManager   = ($profiles.GetEnumerator() | Where-Object { $_.Value -eq "9022" }).Name

Log "Change Default Role Center to 9022"
Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
"USE [$DatabaseName]
GO
UPDATE [dbo].[Profile]
   SET [Default Role Center] = 0
GO
UPDATE [dbo].[Profile]
   SET [Default Role Center] = 1
 WHERE [Role Center ID] = 9022
GO"  -WarningAction SilentlyContinue

Log "Create Desktop Shortcuts"
New-DesktopShortcut -Name "Demo Environment Landing Page"                        -TargetPath "http://$PublicMachineName" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2017 Windows Client"                              -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\$NavVersion\RoleTailored Client\Microsoft.Dynamics.Nav.Client.exe" -Arguments "-Language:$languageCode"
New-DesktopShortcut -Name "NAV 2017 Web Client"                                  -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2017 Tablet Client"                               -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/tablet.aspx" IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2017 Phone Client"                                -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/phone.aspx" IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2017 Development Environment"                     -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\$NavVersion\RoleTailored Client\finsql.exe" -Arguments "servername=localhost\NAVDEMO, database=$DatabaseName, ntauthentication=1"
New-DesktopShortcut -Name "NAV 2017 Administration"                              -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\$NavVersion\RoleTailored Client\Microsoft Dynamics NAV Server.msc" -IconLocation "%SystemRoot%\Installer\{00000000-0000-8000-0000-0CE90DA3512B}\AdminToolsIcon.exe"
New-DesktopShortcut -Name "NAV 2017 Administration Shell"                        -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell.exe" -Arguments ("-NoExit -ExecutionPolicy RemoteSigned & " + "'C:\Program Files\Microsoft Dynamics NAV\$NavVersion\Service\NavAdminTool.ps1'")
New-DesktopShortcut -Name "NAV 2017 Development Shell"                           -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell.exe" -Arguments ("-NoExit -ExecutionPolicy RemoteSigned & " + "'C:\Program Files (x86)\Microsoft Dynamics NAV\$NavVersion\RoleTailored Client\NavModelTools.ps1'")
New-DesktopShortcut -Name "Windows Powershell ISE"                               -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe" -WorkingDirectory "C:\DEMO"
New-DesktopShortcut -Name "Welcome to Microsoft Dynamics NAV on Microsoft Azure" -TargetPath "C:\DEMO\Welcome to Microsoft Dynamics NAV on Microsoft Azure.mht"

Log "Add Help folder to Search Scope"
Add-Type -Path (Join-Path $PSScriptRootV2 'Microsoft.Search.Interop.dll')
#Create an instance of CSearchManagerClass
$sm = New-Object Microsoft.Search.Interop.CSearchManagerClass 
#Next we connect to the SystemIndex catalog
$catalog = $sm.GetCatalog("SystemIndex")
#Get the interface to the scope rule manager
$crawlman = $catalog.GetCrawlScopeManager()
$crawlman.AddUserScopeRule("file:///C:\inetpub\wwwroot\DynamicsNAV${NavVersion}Help\help\en\*", $true, $false, $null)
$crawlman.SaveAll()

Log "Update .mht file"
$mht = [System.IO.File]::ReadAllText("C:\DEMO\Welcome to Microsoft Dynamics NAV on Microsoft Azure.mht", [System.Text.Encoding]::GetEncoding(28591))
$orgWebClientLink = "http://localhost:8080/NAV/WebClient"
$newWebClientLink = "https://$PublicMachineName/$serverInstance/WebClient"
$mht = $mht.Replace($orgWebClientLink, $newWebClientLink)
[System.IO.File]::WriteAllText("C:\DEMO\Welcome to Microsoft Dynamics NAV on Microsoft Azure.mht", $mht, [System.Text.Encoding]::GetEncoding(28591))

$URLsFile = "C:\Users\Public\Desktop\URLs.txt"

("Demo env. Landing page        : http://$PublicMachineName")                                          | Add-Content -Path $URLsFile
("Web Client URL                : https://$PublicMachineName/$serverInstance/WebClient")               | Add-Content -Path $URLsFile
("Tablet Client URL             : https://$PublicMachineName/$serverInstance/WebClient/tablet.aspx")   | Add-Content -Path $URLsFile
("Phone Client URL              : https://$PublicMachineName/$serverInstance/WebClient/phone.aspx")    | Add-Content -Path $URLsFile
("SOAP Services URL             : https://$PublicMachineName" + ":7047/$serverInstance/WS/Services")   | Add-Content -Path $URLsFile
("OData Services URL            : https://$PublicMachineName" + ":7048/$serverInstance/OData/")        | Add-Content -Path $URLsFile
("NAV Admin Username            : $NAVAdminUser")                                                      | Add-Content -Path $URLsFile
("NAV Admin Password            : $NAVAdminPassword")                                                  | Add-Content -Path $URLsFile

# Turn off IE Enhanced Security Configuration
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null

# Enable File Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0

# Enable Font Download in IE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0

Log "Add $CloudServiceName to trusted sites"
$idx = $CloudServiceName.IndexOf('.')
$HostName = $CloudServiceName.Substring(0,$idx)
$Domain = $CloudServiceName.Substring($idx+1)
Push-Location
Set-Location "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
if (!(Test-Path $Domain)) {
    New-Item $Domain | Out-Null
}
Set-Location $Domain
if (!(Test-Path $HostName)) {
    New-Item $HostName | Out-Null
}
Set-Location $HostName
Set-ItemProperty . -Name https -Value 2 -Type DWORD
Pop-Location

Log -kind Success "Virtual Machine Initialization succeeded"

if ([Environment]::UserName -ne "SYSTEM") {
    # Show landing page
    Start-Process "http://$PublicMachineName"
}
