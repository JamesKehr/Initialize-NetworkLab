# setup lab system

[CmdletBinding()]
param (
    [Parameter()]
    [switch]
    $RX,

    [Parameter()]
    [switch]
    $TX,

    [Parameter()]
    [string[]]
    $DnsServer = "192.168.1.60"
)

### FUNCTIONS ###
#region

# FUNCTION: Find-GitReleaseLatest
# PURPOSE:  Calls Github API to retrieve details about the latest release. Returns a PSCustomObject with repro, version (tag_name), and download URL.
function Find-GitReleaseLatest
{
    [CmdletBinding()]
    param(
        [string]$repo
    )

    Write-Verbose "Find-GitReleaseLatest - Begin"

    $baseApiUri = "https://api.github.com/repos/$($repo)/releases/latest"

    # make sure we don't try to use an insecure SSL/TLS protocol when downloading files
    $secureProtocols = @() 
    $insecureProtocols = @( [System.Net.SecurityProtocolType]::SystemDefault, 
                            [System.Net.SecurityProtocolType]::Ssl3, 
                            [System.Net.SecurityProtocolType]::Tls, 
                            [System.Net.SecurityProtocolType]::Tls11) 
    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType])) 
    { 
        if ($insecureProtocols -notcontains $protocol) 
        { 
            $secureProtocols += $protocol 
        } 
    } 
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols

    # get the available releases
    Write-Verbose "Find-GitReleaseLatest - Processing repro: $repo"
    Write-Verbose "Find-GitReleaseLatest - Making Github API call to: $baseApiUri"
    try 
    {
        if ($pshost.Version.Major -le 5)
        {
            $rawReleases = Invoke-WebRequest $baseApiUri -UseBasicParsing -EA Stop
        }
        elseif ($pshost.Version.Major -ge 6)
        {
            $rawReleases = Invoke-WebRequest $baseApiUri -EA Stop
        }
        else 
        {
            return (Write-Error "Unsupported version of PowerShell...?" -EA Stop)
        }
    }
    catch 
    {
        return (Write-Error "Could not get GitHub releases. Error: $_" -EA Stop)        
    }

    Write-Verbose "Find-GitReleaseLatest - Processing results."
    try
    {
        [version]$version = ($rawReleases.Content | ConvertFrom-Json).tag_name
    }
    catch
    {
        $version = ($rawReleases.Content | ConvertFrom-Json).tag_name
    }

    Write-Verbose "Find-GitReleaseLatest - Found version: $version"

    $dlURI = ($rawReleases.Content | ConvertFrom-Json).Assets.browser_download_url

    Write-Verbose "Find-GitReleaseLatest - Found download URL: $dlURI"

    Write-Verbose "Find-GitReleaseLatest - End"

    return ([PSCustomObject]@{
        Repo    = $repo
        Version = $version
        URL     = $dlURI
    })
} #end Find-GitReleaseLatest



# FUNCTION: Get-WebFile
# PURPOSE:  
function Get-WebFile
{
    [CmdletBinding()]
    param ( 
        [string]$URI,
        [string]$savePath,
        [string]$fileName
    )

    Write-Verbose "Get-WebFile - Begin"
    Write-Verbose "Get-WebFile - Attempting to download: $dlUrl"

    # make sure we don't try to use an insecure SSL/TLS protocol when downloading files
    $secureProtocols = @() 
    $insecureProtocols = @( [System.Net.SecurityProtocolType]::SystemDefault, 
                            [System.Net.SecurityProtocolType]::Ssl3, 
                            [System.Net.SecurityProtocolType]::Tls, 
                            [System.Net.SecurityProtocolType]::Tls11) 
    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType])) 
    { 
        if ($insecureProtocols -notcontains $protocol) 
        { 
            $secureProtocols += $protocol 
        } 
    } 
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols

    try 
    {
        Invoke-WebRequest -Uri $URI -OutFile "$savePath\$fileName"
    } 
    catch 
    {
        return (Write-Error "Could not download $URI`: $($Error[0].ToString())" -EA Stop)
    }

    Write-Verbose "Get-WebFile - File saved to: $savePath\$fileName"
    Write-Verbose "Get-WebFile - End"
    return "$savePath\$fileName"
} #end Get-WebFile



function Install-FromGithub
{
    [CmdletBinding()]
    param (
        $repo,
        $extension,
        $savePath
    )

    # appx extensions
    $appxExt = "msixbundle", "appx"

    # download wt
    $release = Find-GitReleaseLatest $repo
    $fileName = "$(($repo -split '/')[-1])`.$extension"

    # find the URL
    $URL = $release.URL | Where-Object { $_ -match "^.*.$extension$" }

    if ($URL -is [array])
    {
        # try to find the URL based on architecture (x64/x86) and OS (Windows)
        if ([System.Environment]::Is64BitOperatingSystem)
        {
            $osArch = "x64"
        }
        else 
        {
            $osArch = "x86"
        }
                
        $URL = $URL | Where-Object { $_ -match $osArch }

        if ($URL -is [array])
        {
            $URL = $URL | Where-Object { $_ -match "win" }

            # can do more, but this is good enough for this script
        }
    }

    try 
    {
        $installFile = Get-WebFile -URI $URL -savePath $savePath -fileName $fileName -EA Stop
        
        if ($extension -in  $appxExt)
        {
            Add-AppxPackage $installFile -EA Stop
        }
        else
        {
            Start-Process "$installFile" -Wait
        }
    }
    catch 
    {
        return (Write-Error "$_" -EA Stop)        
    }
}

function Get-InstalledFonts
{
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    return ((New-Object System.Drawing.Text.InstalledFontCollection).Families)
}

function Install-Font
{
    [CmdletBinding()]
    param (
        [Parameter()]
        $Path
    )

    $FONTS = 0x14
    $CopyOptions = 4 + 16;
    $objShell = New-Object -ComObject Shell.Application
    $objFolder = $objShell.Namespace($FONTS)

    foreach ($font in $Path)
    {
        $CopyFlag = [String]::Format("{0:x}", $CopyOptions);
        $objFolder.CopyHere($font.fullname,$CopyFlag)
    }
}

# https://www.andreasnick.com/112-install-winget-and-appinstaller-on-windows-server-2022.html
function Install-VCLib
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $RepoLocation = $env:Temp
    )

    # make sure we don't try to use an insecure SSL/TLS protocol when downloading files
    $secureProtocols = @() 
    $insecureProtocols = @( [System.Net.SecurityProtocolType]::SystemDefault, 
                            [System.Net.SecurityProtocolType]::Ssl3, 
                            [System.Net.SecurityProtocolType]::Tls, 
                            [System.Net.SecurityProtocolType]::Tls11) 
    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType])) 
    { 
        if ($insecureProtocols -notcontains $protocol) 
        { 
            $secureProtocols += $protocol 
        } 
    } 
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols

    $StoreLink = 'https://www.microsoft.com/en-us/p/app-installer/9nblggh4nns1'
    #$StorePackageName = 'Microsoft.VCLibs.140.00.UWPDesktop_14.0.30035.0_x64__8wekyb3d8bbwe.appx'

    $RepoName = 'AppPackages'
    #$RepoLocation = $env:Temp
    $Packagename = 'Microsoft.VCLibs.140.00.UWPDesktop'
    $RepoPath = Join-Path $RepoLocation -ChildPath $RepoName 
    $RepoPath = Join-Path $RepoPath -ChildPath $Packagename

    
    #
    # Function Source
    # Idea from: https://serverfault.com/questions/1018220/how-do-i-install-an-app-from-windows-store-using-powershell
    # modificated version. Now able to filte and return msix url's
    #

    function Get-AppPackage {
        [CmdletBinding()]
        param (
            [string]$Uri,
            [string]$Filter = '.*' #Regex
        )
            
        process {   
            #$Uri=$StoreLink

            $WebResponse = Invoke-WebRequest -UseBasicParsing -Method 'POST' -Uri 'https://store.rg-adguard.net/api/GetFiles' -Body "type=url&url=$Uri&ring=Retail" -ContentType 'application/x-www-form-urlencoded'
            
            $result = $WebResponse.Links.outerHtml | Where-Object {($_ -like '*.appx*') -or ($_ -like '*.msix*')} | Where-Object {$_ -like '*_neutral_*' -or $_ -like "*_"+$env:PROCESSOR_ARCHITECTURE.Replace("AMD","X").Replace("IA","X")+"_*"} | ForEach-Object {
                $result = "" | Select-Object -Property filename, downloadurl
                
                if( $_ -match '(?<=rel="noreferrer">).+(?=</a>)' )
                {
                    $result.filename = $matches.Values[0]
                }

                if( $_ -match '(?<=a href=").+(?=" r)' )
                {
                    $result.downloadurl = $matches.Values[0]
                }
                $result
            } 
            
            $result | Where-Object -Property filename -Match $filter 
        }
    }

    $package = Get-AppPackage -Uri $StoreLink  -Filter $Packagename

    if ($package.downloadurl -notmatch "http://.*microsoft.com/filestreamingservice")
    {
        return (Write-Error "Invalid download url: $($package.downloadurl)")
    }

    if(-not (Test-Path $RepoPath ))
    {
        New-Item $RepoPath -ItemType Directory -Force
    }

    if(-not (Test-Path (Join-Path $RepoPath -ChildPath $package.filename )))
    {
        Invoke-WebRequest -Uri $($package.downloadurl) -OutFile (Join-Path $RepoPath -ChildPath $package.filename )
    } else 
    {
        Write-Information "The file $($package.filename) already exist in the repo. Skip download"
    }

    #Install the Runtime
    Add-AppxPackage (Join-Path $RepoPath -ChildPath $package.filename )
}


#endregion FUNCTIONS


### CONSTANTS ###
#region

if ($TX.IsPresent)
{
    # rename the computer
    Rename-Computer -NewName GEARS-RX

    # look for the BLUE adapter
    $blueNIC = Get-NetAdapter BLUE -EA SilentlyContinue
    if ($blueNIC)
    {
        $blueIP = Get-NetIPAddress -InterfaceAlias BLUE -AddressFamily IPv4

        if ($blueIP.SuffixOrigin -ne "Manual")
        {
            New-NetIPAddress -InterfaceAlias BLUE -AddressFamily IPv4 -IPAddress 10.2.0.2 -PrefixLength 24 -DefaultGateway 10.2.0.1
            Set-DnsClientServerAddress -InterfaceAlias BLUE -ServerAddresses $DnsServer
        }
    }

    # look for the GREEN adapter
    $greenNIC = Get-NetAdapter GREEN -EA SilentlyContinue
    if ($greenNIC)
    {
        $greenIP = Get-NetIPAddress -InterfaceAlias GREEN -AddressFamily IPv4 -EA SilentlyContinue

        if ($greenIP.SuffixOrigin -ne "Manual")
        {
            New-NetIPAddress -InterfaceAlias GREEN -AddressFamily IPv4 -IPAddress 10.3.0.2 -PrefixLength 24
        }
    }

}
elseif ($RX.IsPresent) 
{
    # rename the computer
    Rename-Computer -NewName GEARS-RX

    # look for the RED adapter
    $redNIC = Get-NetAdapter RED -EA SilentlyContinue
    if ($redNIC)
    {
        $redIP = Get-NetIPAddress -InterfaceAlias RED -AddressFamily IPv4 -EA SilentlyContinue

        if ($redIP.SuffixOrigin -ne "Manual")
        {
            New-NetIPAddress -InterfaceAlias RED -AddressFamily IPv4 -IPAddress 10.1.0.2 -PrefixLength 24 -DefaultGateway 10.1.0.1
            Set-DnsClientServerAddress -InterfaceAlias BLUE -ServerAddresses $DnsServer
        }
    }

    # look for the GREEN adapter
    $greenNIC = Get-NetAdapter GREEN -EA SilentlyContinue
    if ($greenNIC)
    {
        $greenIP = Get-NetIPAddress -InterfaceAlias GREEN -AddressFamily IPv4

        if ($greenIP.SuffixOrigin -ne "Manual")
        {
            New-NetIPAddress -InterfaceAlias GREEN -AddressFamily IPv4 -IPAddress 10.3.0.1 -PrefixLength 24
        }
    }
}


# where to put downloads
$savePath = "C:\Temp"

# list of exact winget app IDs to install
[array]$wingetApps = "Microsoft.PowerShell", "Microsoft.WindowsTerminal", "JanDeDobbeleer.OhMyPosh", "WiresharkFoundation.Wireshark"

# winget repro and file extension
$wingetRepo = "microsoft/winget-cli"
$wingetExt = "msixbundle"

# repro for Caskaydia Cove Nerd Font
$repoCCNF = "ryanoasis/nerd-fonts"

# name of the preferred pretty font, CaskaydiaCove NF
$fontName = "CaskaydiaCove NF"

# the zip file where CC NF is in
$fontFile = "CascadiaCode.zip"

# list of commands to add to the PowerShell profile
[string[]]$profileLines = 'Import-Module -Name Terminal-Icons',
                          'oh-my-posh --init --shell pwsh --config ~/jandedobbeleer.omp.json | Invoke-Expression',
                          'Set-PoshPrompt slimfat',
                          'New-PSDrive -Name Lab -PSProvider FileSystem -Root $env:USERPROFILE\Desktop\Scripts\',
                          'CD lab:',
                          'cls'

# where lab files go
$labFiles = "$env:USERPROFILE\Desktop\Scripts"

# ntttcp repo
$repoNtttcp = "microsoft/ntttcp"

# iPerf download URL
$iperfURL = "https://files.budman.pw/iperf3.10.1_64bit.zip"

# npcap URL
$npcapURL = "https://nmap.org/npcap/dist/npcap-1.60.exe"

# TAT.Net URL
$tatURL = "https://github.com/TextAnalysisTool/Releases/raw/master/TextAnalysisTool.NET.zip"


#endregion CONSTANTS



### MAIN ###

$null = mkdir $savePath -EA SilentlyContinue
$null = mkdir $env:USERPROFILE\Desktop\Scripts -EA SilentlyContinue


## install winget on WS2022 ##
# install VCLiv depenency
Install-VCLib -RepoLocation $savePath

# download and install winget from github
try 
{
    $release = Find-GitReleaseLatest $wingetRepo
    $fileName = "$(($wingetRepo -split '/')[-1])`.$wingetExt"

    # find the URL
    $URL = $release.URL | Where-Object { $_ -match "^.*.$wingetExt$" }

    $installFile = Get-WebFile -URI $URL -savePath $savePath -fileName $fileName -EA Stop

    $URL2 = $release.URL | Where-Object { $_ -match "^.*.xml$" }
    $fileName2 = Split-Path $url2 -Leaf

    $licenseFile = Get-WebFile -URI $URL2 -savePath $savePath -fileName $fileName2 -EA Stop

    Add-AppxProvisionedPackage -Online -PackagePath $installFile -LicensePath $licenseFile -Verbose -EA Stop
}
catch
{
    return (Write-Error "Winget download failed: $_" -EA Stop)
}

## install winget apps ##
$count = 0
do
{
    Start-Sleep 1
    $wingetFnd = Get-Command winget -EA SilentlyContinue
    $count++
} until ($wingetFnd -or $count -ge 10)

if ($wingetFnd)
{
    foreach ($app in $wingetApps)
    {
        # install things
        winget install $app --exact --accept-package-agreements --accept-source-agreements --silent
    }
}
else
{
    return (Write-Error "Winget installation failed: Winget not found." -EA Stop)
}


## configure PowerShell on Windows Terminal ##
# get CaskaydiaCove NF if not installed
if ($fontName -notin (Get-InstalledFonts))
{
    Write-Verbose "Installing $fontName"
    # get newest font
    $ccnf = Find-GitReleaseLatest -repo $repoCCNF    

    # find the correct URL
    $ccnfURL = $ccnf.URL | Where-Object {$_ -match $fontFile}

    # download
    try 
    {
        $ccnfZip = Get-WebFile -URI $ccnfURL -savePath $savePath -fileName $fontFile    
    }
    catch 
    {
        Write-Error "Failed to download $fontFile. Please download and install $fontName manually, or the Nerd Font of your choice."
    }
    
    # extract
    $extractPath = "$savePath\ccnf"
    Expand-Archive -Path $ccnfZip -DestinationPath $extractPath -Force

    # install fonts
    Install-Font (Get-ChildItem "$extractPath" -Filter "*.ttf" -EA SilentlyContinue)

    Start-Sleep 30
}

## install modules ##

[scriptblock]$cmd = {
    $nugetVer = Get-PackageProvider -ListAvailable -EA SilentlyContinue | Where-Object Name -match "NuGet" | ForEach-Object { $_.Version }
    [version]$minNugetVer = "2.8.5.208"
    if ($nugetVer -lt $minNugetVer -or $null -eq $nugetVer)
    {
        Write-Verbose "Installing NuGet update."
        $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
    }

    # get module(s)
    Install-Module -Name Terminal-Icons,oh-my-posh -Repository PSGallery -Scope CurrentUser -Force
}

# update $env:Path so pwsh will be found
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

# install pwsh modules
pwsh -NoLogo -NoProfile -Command $cmd



# update the pwsh profile
$pwshProfilePath = pwsh -NoLogo -NoProfile -Command { $PROFILE } 

$pwshProfile = Get-Content $pwshProfilePath -EA SilentlyContinue

if (-NOT (Test-path $pwshProfilePath)) { $null = New-Item $pwshProfilePath -ItemType File -Force }

foreach ($line in $profileLines)
{
    if ($line -notin $pwshProfile)
    {
        $line | Out-File "$pwshProfilePath" -Append -Force
    }
}

# assume WT is installed at this point
# launch WT once to make sure settings.json is generated
Start-Process wt -ArgumentList "-p PowerShell" -WindowStyle Minimized
Start-Sleep 10
Get-Process WindowsTerminal | Stop-Process -Force

$appxPack = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -EA SilentlyContinue
$wtAppData = "$ENV:LOCALAPPDATA\Packages\$($appxPack.PackageFamilyName)\LocalState"

# export settings.json
# clean up comment lines to prevent issues with older JSON parsers (looking at you Windows PowerShell)
try 
{
    $wtJSON =  Get-Content "$wtAppData\settings.json" -EA Stop | Where-Object { $_ -notmatch "^.*//.*$" -and $_ -ne "" -and $_ -ne $null} | ConvertFrom-Json    
}
catch 
{
    return (Write-Error "Failed to update Windows Terminal settings." -EA Stop)
}

# change the font for PowerShell
if ($null -ne $wtJSON.profiles.list.font.face)
{
    $wtJSON.profiles.list | Where-Object { $_.Name -eq "PowerShell" } | ForEach-Object { $_.Font.Face = $fontName }
}
else 
{
    $pwshProfile = $wtJSON.profiles.list | Where-Object { $_.Name -eq "PowerShell" }
    $pwshProfile | Add-Member -NotePropertyName font -NotePropertyValue ([PSCustomObject]@{face="$fontName"})
}

# set PowerShell (pwsh) to the default profil
$pwshGUID = $wtJSON.profiles.list | Where-Object Name -eq "PowerShell" | ForEach-Object { $_.guid }

if ($pwshGUID)
{
    $defaultGUID = $wtJSON.defaultProfile

    if ($defaultGUID -ne $pwshGUID)
    {
        $wtJSON.defaultProfile = $pwshGUID
    }
}

# change some WT defaults... 
$evilPasteSettings = 'largePasteWarning', 'multiLinePasteWarning'

foreach ($imp in $evilPasteSettings)
{
    if ($null -eq $wtJSON."$imp" -or $wtJSON."$imp" -eq $true)
    {
        $wtJSON | Add-Member -NotePropertyName $imp -NotePropertyValue $false -Force
    }
}

# maximize wt on start
$wtJSON | Add-Member -NotePropertyName "launchMode" -NotePropertyValue "maximized" -Force


# save settings
$wtJSON | ConvertTo-Json -Depth 20 | Out-File "$wtAppData\settings.json" -Force -Encoding utf8


# get ntttcp
$ntttcpURL = Find-GitReleaseLatest -repo $repoNtttcp

try 
{
    $null = Get-WebFile -URI $ntttcpURL.URL -savePath $labFiles -fileName ntttcp.exe
    New-NetFirewallRule -DisplayName "ntttcp (TCP-In)" -Name "ntttcp_tcp_in" -Description "Allows ntttcp traffic." -Program "$labFiles\ntttcp.exe" -Direction Inbound -Protocol TCP -Action Allow
}
catch 
{
    Write-Warning "Failed to download ntttcp. Please manually download."    
}


# get iPerf
try 
{
    $iperfFile = Get-WebFile -URI $iperfURL -savePath $labFiles -fileName iperf.zip
    Expand-Archive -Path $iperfFile -DestinationPath $labFiles -Force -EA SilentlyContinue
    $iperfDir = Get-ChildItem $labFiles -Directory -Filter "iperf*"
    Move-Item "$($iperfDir.FullName)\*" $labFiles -Force
    $null = Remove-Item $($iperfDir.FullName) -Force
    $null = Remove-Item $iperfFile -Force
    New-NetFirewallRule -DisplayName "iPerf (TCP-In)" -Name "iperf_tcp_in" -Description "Allows iPerf traffic." -Program "$labFiles\iperf3.exe" -Direction Inbound -Protocol TCP -Action Allow
}
catch 
{
    Write-Warning "Failed to download iPerf. Please manually download."
}


# get npcap
try 
{
    $npcapFile = Get-WebFile -URI $npcapURL -savePath $labFiles -fileName npcap.exe
    Start-Process "$labFiles\npcap.exe" -ArgumentList "/winpcap_mode=disabled" -Wait

    $null = Remove-Item $npcapFile -Force
}
catch 
{
    Write-Warning "Failed to download and install npcap. Please manually download and install: $_"
}

# get TAT.NET
try 
{
    $tatFile = Get-WebFile -URI $tatURL -savePath $labFiles -fileName tat.zip
    Expand-Archive $tatFile
    Get-ChildItem .\tat -File | ForEach-Object { Move-Item $($_.FullName) -Force }

    $null = Remove-Item $tatFile -Force
    $null = Remove-Item .\tat -Recurse -Force
}
catch 
{
    Write-Warning "Failed to download and install TextAnalyzerTool. Please manually download and install: $_"
}

# add Open With TAT


# update and reboot
Install-PackageProvider -Name NuGet -Force
Install-Module -Name PSWindowsUpdate -MinimumVersion 2.2.0 -Force
Get-WindowsUpdate -AcceptAll -Verbose -WindowsUpdate -Install -AutoReboot
Restart-Computer -Force
