# Initialize-NetworkLab
PowerShell script built to configure Windows Server 2022 as a network lab.

## Generic Setup

The script can be run live using this command from an elevated (Run as administrator) PowerShell console. This does not perform any computer renaming or IP address configuration of the RED, BLUE, or GREEN networks.

```PowerShell
iwr https://raw.githubusercontent.com/JamesKehr/Initialize-NetworkLab/main/Initialize-NetworkLab.ps1 | iex
```

iwr is the alias for Invoke-WebRequest.

iex is the alias for Invoke-Expression.

## RX Setup

Use these commands to setup the RX (reciever) computer.

```PowerShell
iwr https://raw.githubusercontent.com/JamesKehr/Initialize-NetworkLab/main/Initialize-NetworkLab.ps1 -OutFile "$ENV:USERPROFILE\Desktop\Initialize-NetworkLab.ps1"
Set-Location "$ENV:USERPROFILE\Desktop"
.\Initialize-NetworkLab.ps1 -RX
```

## TX Setup

Use these commands to setup the TX (transmit) computer.

```PowerShell
iwr https://raw.githubusercontent.com/JamesKehr/Initialize-NetworkLab/main/Initialize-NetworkLab.ps1 -OutFile "$ENV:USERPROFILE\Desktop\Initialize-NetworkLab.ps1"
Set-Location "$ENV:USERPROFILE\Desktop"
.\Initialize-NetworkLab.ps1 -TX
```
