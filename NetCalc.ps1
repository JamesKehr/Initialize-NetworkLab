[CmdletBinding()]
param ()

##### FUNCTIONS #####
#region

function PreviewKeyDownDigiDot
{
    [CmdletBinding()]
    param (
        [string]$dot,
        $e
    )

    [bool]$dotBool = Invoke-Expression "`$$dot"

    $var_tbkBdpResults.Text = "e.Key: $($e.Key)"

    switch -Regex ($e.Key.ToString())
    {
        "[0-9]"  { return $false }

        {$_ -eq "OemPeriod" -or $_ -eq "Decimal"}
        {
            if ($dotBool -eq $false) 
            {
                Invoke-Expression "`$$dot = `$true"

                return $false            
            }
            else
            {
                return $true
            }
        }

        "Back"   { return $false }

        "Tab"    { return $false }

        "Left"   { return $false }

        "Right"   { return $false }

        "Delete" { return $false }

        default  { return $true}
    }
}

function PreviewKeyDownDigi
{
    [CmdletBinding()]
    param (
        $e
    )

    switch -Regex ($e.Key.ToString())
    {
        "[0-9]"  { return $false }

        "Back"   { $var_tbkBdpResults.Text = "result back: $($e.Text) = $($e.Key) = $result"; return $false }

        "Tab"    { return $false }

        "Left"   { return $false }

        "Right"  { return $false }

        "Delete" { return $false }

        default  { $var_tbkBdpResults.Text = "result dflt: $($e.Text) = $($e.Key) = $result"; return $true}
    }
}

function Find-BPD
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $BPD,

        [Parameter()]
        [decimal]
        $B,

        [Parameter()]
        [decimal]
        $RTT
    )

    # find BDP from B and RTT
    if ($B -gt 0 -and $RTT -gt 0)
    {
        return ( ($B * $RTT) / 8 )
    }
    # find B from BDP and RTT
    elseif ($BDP -gt 0 -and $RTT -gt 0)
    {
        return ( ($BDP / $RTT) * 8 )
    }
    # find RTT from B and BDP
    elseif ($B -gt 0 -and $B -gt 0)
    {
        return ( ($BDP / $B) * 8 )
    }
    # something went wrong, throw an error
    else
    {
        return $null
    }
}


function Convert-Byte2Byte
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $num,

        [Parameter()]
        [string]
        $unit
    )

    switch ($unit)
    {
        "B"     { return $num }
        "KB"    { return ($num * 1KB) }
        "MB"    { return ($num * 1MB) }
        "GB"    { return ($num * 1GB) }
        "TB"    { return ($num * 1TB) }
        "PB"    { return ($num * 1PB) }
        "EB"    { return ($num * 1PB * 1KB) }
        default { return $null}
    }
}

function Convert-Bs2bps
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $num,

        [Parameter()]
        [string]
        $unit
    )

    switch ($unit)
    {
        "B/s"     { return ($num * 8)}
        "KB/s"    { return ($num * 8 * [math]::Pow(10,3)) }
        "MB/s"    { return ($num * 8 * [math]::Pow(10,6)) }
        "GB/s"    { return ($num * 8 * [math]::Pow(10,9)) }
        "TB/s"    { return ($num * 8 * [math]::Pow(10,12)) }
        "PB/s"    { return ($num * 8 * [math]::Pow(10,15)) }
        default { return $null}
    }
}

function Convert-bps2Bs
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $num,

        [Parameter()]
        [string]
        $unit
    )

    switch ($unit)
    {
        "bps"     { return ($num / 8)}
        "Kbps"    { return ($num / 8 * [math]::Pow(10,3)) }
        "Mbps"    { return ($num / 8 * [math]::Pow(10,6)) }
        "Gbps"    { return ($num / 8 * [math]::Pow(10,9)) }
        "Tbps"    { return ($num / 8 * [math]::Pow(10,12)) }
        "Pbps"    { return ($num / 8 * [math]::Pow(10,15)) }
        default   { return $null}
    }
}

function Convert-Bit2Bit
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $num,

        [Parameter()]
        [string]
        $unit
    )

    switch ($unit)
    {
        "bps"     { return $num }
        "Kbps"    { return ($num * [math]::Pow(10,3)) }
        "Mbps"    { return ($num * [math]::Pow(10,6)) }
        "Gbps"    { return ($num * [math]::Pow(10,9)) }
        "Tbps"    { return ($num * [math]::Pow(10,12)) }
        # these seem awfully optimistic
        "Pbps"    { return ($num * [math]::Pow(10,15)) }
        "Ebps"    { return ($num * [math]::Pow(10,18)) }
        default { return $null}
    }
}

function Convert-Sec2Sec
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $num,

        [Parameter()]
        [string]
        $unit
    )

    switch ($unit)
    {
        "s"     { return $num }
        "ms"    { return ($num * [math]::Pow(10,-3)) }
        "µs"    { return ($num * [math]::Pow(10,-6)) }
        "ns"    { return ($num * [math]::Pow(10,-9)) }
        default { return $null}
    }
}

function Convert-Bit2Byte
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $num
    )

    return ($num / 8)
}

function Convert-Byte2Bit
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [decimal]
        $num
    )

    return ($num * 8)
}

function Convert-LeftSec2RightSec
{
    # read GB/s
    [decimal]$secLeft = $var_tbxConvSecLeft.Text
    [string]$secLeftUnit = $var_cbxConvSecLeft.SelectedItem.Content.split(" ")[0]

    ##$output += "0: $secLeft $secLeftUnit = $secRight $secRightUnit`n"

    # convert to seconds
    $secLeft = Convert-Sec2Sec $secLeft $secLeftUnit

    # get the right unit of measure
    [string]$secRightUnit = $var_cbxConvSecRight.SelectedItem.Content.split(" ")[0]

    #$output += "1: $secLeft $secLeftUnit = $secRight $secRightUnit`n"

    # convert to the right side
    switch ($secRightUnit) {
        "s"     { $secRight = [math]::Round($secLeft, 12) }
        "ms"    { $secRight = [math]::Round($secLeft / [math]::Pow(10,-3), 2) }
        "µs"    { $secRight = [math]::Round($secLeft / [math]::Pow(10,-6), 2) }
        "ns"    { $secRight = [math]::Round($secLeft / [math]::Pow(10,-9), 2) }
        default { 
            $var_tbkBdpResults.Text = "Unknown unit: $secRightUnit"
            return $null
        }
    }
    
    # set Gbps
    #$output += "2: $secLeft $secLeftUnit = $secRight $secRightUnit"
    #$var_tbkBdpResults.Text = $output
    $var_tbxConvSecRight.Text = ($secRight -as [decimal])
}

function Convert-RightSec2LeftSec
{
    # read GB/s
    [decimal]$secRight = $var_tbxConvSecRight.Text
    [string]$secRightUnit = $var_cbxConvSecRight.SelectedItem.Content.split(" ")[0]

    # convert to seconds
    $secRight = Convert-Sec2Sec $secRight $secRightUnit

    # get the right unit of measure
    [string]$secLeftUnit = $var_cbxConvSecLeft.SelectedItem.Content.split(" ")[0]

    # convert to the right side
    switch ($secLeftUnit) {
        "s"     { $secLeft = [math]::Round($secRight, 12) }
        "ms"    { $secLeft = [math]::Round($secRight / [math]::Pow(10,-3), 2) }
        "µs"    { $secLeft = [math]::Round($secRight / [math]::Pow(10,-6), 2) }
        "ns"    { $secLeft = [math]::Round($secRight / [math]::Pow(10,-9), 2) }
        default { 
            $var_tbkBdpResults.Text = "Unknown unit: $secLeftUnit"
            return $null
        }
    }
    
    # set Gbps
    $var_tbkBdpResults.Text = "$secLeft $secLeftUnit = $secRight $secRightUnit"
    $var_tbxConvSecLeft.Text = ($secLeft -as [decimal])
}

#endregion

##### CONSTANTS #####
#region

# BDP formulas
#$bdpFormula = "Bandwidth Delay Product (BDP) = Bandwidth * Round-Trip Time"
#$bFormula = "Round-Trip Time = Bandwidth Delay Product (BDP) / Bandwidth"
#$rttFormula = "Bandwidth = Bandwidth Delay Product (BDP) / Round-Trip Time"

# BDP tab dot controls
[bool]$script:dotBdpB = $false
[bool]$script:dotBdpBdp = $false
[bool]$script:dotBdpRtt = $false

# Mathis tab dot controls
[bool]$script:dotMathisMss = $false
[bool]$script:dotMathisRtt = $false
[bool]$script:dotMathisP = $false

# create aliases
Set-Item -Path Alias:b2bb -Value Convert-Bit2Byte
Set-Item -Path Alias:bb2b -Value Convert-Byte2Bit



# the UI XAML from Visual Studio goes here to make this a single file solution.
# Based on: https://adamtheautomator.com/powershell-gui/
[XML]$XAML = @'
<Window x:Class="LabCalc.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:LabCalc"
        mc:Ignorable="d"
        Title="Network Lab Calculator" Height="450" Width="828">
    <Grid Margin="10,34,3.6,7">
        <TabControl Margin="0,-22,0.4,0">
            <TabItem Header="BDP">
                <StackPanel Height="341" Margin="0,0,18,0">
                    <Label Content="Bandwidth Delay Product (BDP) = Bandwidth * Round-Trip Time" Margin="0,0,-34,0" HorizontalAlignment="Left" VerticalAlignment="Center" FontFamily="Consolas" FontSize="14"/>
                    <StackPanel Height="66" Orientation="Horizontal" Margin="0,0,-20,0">
                        <Label Content="BDP [cwnd]" Width="185" FontFamily="Consolas" FontSize="24" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox x:Name="tbxBdpBdp" TextWrapping="Wrap" Width="365" HorizontalAlignment="Left" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24"/>
                        <ComboBox x:Name="cbxBdpBdp" Width="241" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24" SelectedIndex="0">
                            <ComboBoxItem Content="B  [bytes]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="KB [kilobyte]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="MB [megabyte]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="GB [gigabyte]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </ComboBox>
                    </StackPanel>
                    <StackPanel Height="66" Orientation="Horizontal" Margin="0,0,-20,0">
                        <Label Content="B   [tput]" Width="185" FontFamily="Consolas" FontSize="24" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox x:Name="tbxBdpB"  TextWrapping="Wrap" Width="365" HorizontalAlignment="Left" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24"/>
                        <ComboBox x:Name="cbxBdpB" Width="241" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24" SelectedIndex="3">
                            <ComboBoxItem Content="bps  [bits/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="Kbps [kilobit/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="Mbps [megabit/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="Gbps [gigabit/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </ComboBox>
                    </StackPanel>
                    <StackPanel Height="66" Orientation="Horizontal" Margin="0,0,-20,0">
                        <Label Content="RTT [latency]" Width="185" FontFamily="Consolas" FontSize="24" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox x:Name="tbxBdpRTT" TextWrapping="Wrap" Width="365" HorizontalAlignment="Left" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24"/>
                        <ComboBox x:Name="cbxBdpRTT" Width="241" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24" SelectedIndex="2">
                            <ComboBoxItem Content="ns [nanosecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="µs [microsecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="ms [milisecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="s  [second]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </ComboBox>
                    </StackPanel>
                    <StackPanel Height="32" Orientation="Horizontal" Margin="0,0,-34,0">
                        <Label Content="" Margin="0,0,0,0.2" Width="257"/>
                        <Button x:Name="btnBdpCalc" Content="Calc" Width="75" HorizontalAlignment="Center" VerticalAlignment="Center" FontFamily="Consolas" FontSize="18" Background="#FF92EBA6"/>
                        <Label Content="        " FontFamily="Consolas"/>
                        <Button x:Name="btnBdpCls" Content="Clear" Width="75" FontFamily="Consolas" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#FFF6C5B7"/>
                    </StackPanel>
                    <TextBox x:Name="tbkBdpResults" IsReadOnly="True" TextWrapping="Wrap" Text="Output" Height="84" Margin="186,0,215,0" FontFamily="Consolas" FontSize="18"/>
                </StackPanel>
            </TabItem>
            <TabItem Header="Mathis">
                <StackPanel Height="351" Width="802">
                    <Label Content="Max Goodput &lt; (MSS  * sqrt(3/2)) / (RTT * sqrt(p)) [Antunes Variation]" HorizontalAlignment="Left" VerticalAlignment="Center" FontFamily="Consolas" FontSize="14"/>
                    <StackPanel Height="66" Orientation="Horizontal" >
                        <Label Content="MSS [TCP]" Width="233" FontFamily="Consolas" FontSize="24" VerticalAlignment="Center" FontWeight="Bold"/>
                        <TextBox x:Name="tbxMathisMss" Text="1460" TextWrapping="Wrap" Width="312" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24" Margin="0,18"/>
                        <Label Content="B [bytes]" FontFamily="Consolas" FontSize="24" FontWeight="Bold" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Height="66" Orientation="Horizontal" >
                        <Label Content="RTT [latency]" Width="233" FontFamily="Consolas" FontSize="24" VerticalAlignment="Center" FontWeight="Bold"/>
                        <TextBox x:Name="tbxMathisRtt" TextWrapping="Wrap" Width="312" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24" Margin="0,18"/>
                        <ComboBox x:Name="cbxMathisRTT" Width="241" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24" SelectedIndex="2">
                            <ComboBoxItem Content="ns [nanosecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="µs [microsecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="ms [milisecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            <ComboBoxItem Content="s  [second]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </ComboBox>
                    </StackPanel>
                    <StackPanel Height="66" Orientation="Horizontal" >
                        <Label Content="Loss [percent]" Width="233" FontFamily="Consolas" FontSize="24" VerticalAlignment="Center" FontWeight="Bold"/>
                        <TextBox x:Name="tbxMathisP" TextWrapping="Wrap" Width="312" VerticalAlignment="Center" FontFamily="Consolas" FontSize="24"/>
                        <Label Content="%" FontFamily="Consolas" FontSize="24" FontWeight="Bold" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Height="32" Orientation="Horizontal" Margin="0,0,-34,0">
                        <Label Content="" Margin="0,0,0,0.2" Width="257"/>
                        <Button x:Name="btnMathisCalc" Content="Calc" Width="75" HorizontalAlignment="Center" VerticalAlignment="Center" FontFamily="Consolas" FontSize="18" Background="#FF92EBA6"/>
                        <Label Content="        " FontFamily="Consolas"/>
                        <Button x:Name="btnMathisCls" Content="Clear" Width="75" FontFamily="Consolas" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#FFF6C5B7"/>
                    </StackPanel>
                    <TextBox x:Name="tbkMathisResults" IsReadOnly="True" TextWrapping="Wrap" Text="Output" Height="84" Margin="186,0,215,0" FontFamily="Consolas" FontSize="18"/>
                </StackPanel>
            </TabItem>
            <TabItem Header="Conversion">
                <StackPanel Height="351" Width="800">
                    <StackPanel Height="100">
                        <Label Content="B/s &lt;-&gt; bps" FontWeight="Bold" FontFamily="Consolas" FontSize="14"/>
                        <StackPanel Height="100" Orientation="Horizontal">
                            <TextBox x:Name="tbxConvB2BLeft" TextWrapping="NoWrap" Width="125" Margin="0,10,0,60" FontFamily="Consolas" FontSize="22" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <ComboBox x:Name="cbxConvB2BLeft" Width="245" Margin="0,8,0,58" FontFamily="Consolas" FontSize="20" VerticalAlignment="Center" SelectedIndex="3" HorizontalAlignment="Left">
                                <ComboBoxItem Content="B/s  [bytes/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="KB/s [kilobytes/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="MB/s [megabytes/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="GB/s [gigabytes/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </ComboBox>
                            <Label Content="&lt;-&gt;" Margin="0,0,0,50" Width="50" FontFamily="Consolas" FontSize="22" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                            <TextBox x:Name="tbxConvB2BRight" TextWrapping="NoWrap" Width="125" Margin="0,10,0,60" FontFamily="Consolas" FontSize="20" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <ComboBox x:Name="cbxConvB2BRight" Width="245" Margin="0,8,0,58" FontFamily="Consolas" FontSize="22" VerticalAlignment="Center" SelectedIndex="3" HorizontalAlignment="Left">
                                <ComboBoxItem Content="bps  [bits/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="Kbps [kilobit/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="Mbps [megabit/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="Gbps [gigabit/s]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </ComboBox>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Height="100">
                        <Label Content="Seconds" FontWeight="Bold" FontFamily="Consolas" FontSize="14"/>
                        <StackPanel Height="100" Orientation="Horizontal">
                            <TextBox x:Name="tbxConvSecLeft" TextWrapping="NoWrap" Width="125" Margin="0,10,0,56" FontFamily="Consolas" FontSize="22" VerticalAlignment="Center" Height="34" HorizontalAlignment="Left"/>
                            <ComboBox x:Name="cbxConvSecLeft" Width="241" VerticalAlignment="Center" FontFamily="Consolas" FontSize="20" SelectedIndex="2" Height="34" Margin="0,10,0,56">
                                <ComboBoxItem Content="ns [nanosecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="µs [microsecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="ms [milisecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="s  [second]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </ComboBox>
                            <Label Content="&lt;-&gt;" Margin="0,0,0,50" Width="50" FontFamily="Consolas" FontSize="24" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                            <TextBox x:Name="tbxConvSecRight" TextWrapping="NoWrap" Width="125" Margin="0,10,0,56" FontFamily="Consolas" FontSize="22" VerticalAlignment="Center" Height="34" HorizontalAlignment="Left"/>
                            <ComboBox x:Name="cbxConvSecRight" Width="241" VerticalAlignment="Center" FontFamily="Consolas" FontSize="20" SelectedIndex="3" Height="34" Margin="0,10,0,56" HorizontalAlignment="Left">
                                <ComboBoxItem Content="ns [nanosecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="µs [microsecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="ms [milisecond]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="s  [second]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </ComboBox>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Height="100">
                        <Label Content="B &lt;-&gt; b" FontWeight="Bold" FontFamily="Consolas" FontSize="14"/>
                        <StackPanel Height="100" Orientation="Horizontal">
                            <TextBox x:Name="tbxConvBLeft" TextWrapping="NoWrap" Width="125" Margin="0,10,0,60" FontFamily="Consolas" FontSize="22" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <ComboBox x:Name="cbxConvBLeft" Width="245" Margin="0,8,0,58" FontFamily="Consolas" FontSize="20" VerticalAlignment="Center" SelectedIndex="0" HorizontalAlignment="Left">
                                <ComboBoxItem Content="B  [byte]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="KB [kilobyte]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="MB [megabyte]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="GB [gigabyte]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </ComboBox>
                            <Label Content="&lt;-&gt;" Margin="0,0,0,50" Width="50" FontFamily="Consolas" FontSize="24" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                            <TextBox x:Name="tbxConvBRight" TextWrapping="NoWrap" Width="125" Margin="0,10,0,60" FontFamily="Consolas" FontSize="22" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <ComboBox x:Name="cbxConvBRight" Width="245" Margin="0,8,0,58" FontFamily="Consolas" FontSize="20" VerticalAlignment="Center" SelectedIndex="0" HorizontalAlignment="Left">
                                <ComboBoxItem Content="b  [bits]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="Kb [kilobit]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="Mb [megabit]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                                <ComboBoxItem Content="Gb [gigabit]" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                            </ComboBox>
                        </StackPanel>
                    </StackPanel>
                    <StackPanel Height="32" Orientation="Horizontal" Margin="0,0,-34,0">
                        <Label Content="" Margin="0,0,0,0.2" Width="360"/>
                        <Button x:Name="btnConvRst" Content="Reset" Width="75" FontFamily="Consolas" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#FFF6C5B7"/>
                    </StackPanel>
                </StackPanel>
            </TabItem>
        </TabControl>
    </Grid>
</Window>
'@ -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'

#endregion

##### MAIN #####

#### FORM setup ####
#region
# load WPF assembly
if (-NOT ([appdomain]::currentdomain.GetAssemblies() | Where-Object Location -match 'PresentationFramework'))
{
    Add-Type -AssemblyName PresentationFramework
}


#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_*
#endregion

##### ADD EVENTS #####

#### BDP Tab ####
#region

$var_btnBdpCls.Add_Click({
    #$var_tbkBdpResults.Clear()
    $var_tbxBdpB.Clear()
    $var_tbxBdpBdp.Clear()
    $var_tbxBdpRTT.Clear()

    [bool]$script:dotBdpB = $false
    [bool]$script:dotBdpBdp = $false
    [bool]$script:dotBdpRtt = $false
})

# calculate BDP
$var_btnBdpCalc.Add_Click({
    # convert all form values to double
    try 
    {
        [decimal]$BDP = $var_tbxBdpBdp.Text
        [decimal]$B   = $var_tbxBdpB.Text
        [decimal]$RTT = $var_tbxBdpRTT.Text
        #[decimal]$B   = [decimal]::TryParse( $var_tbxBdpB.Text.ToString(), [ref]1.1)
        #[decimal]$RTT = [decimal]::TryParse( $var_tbxBdpRTT.Text.ToString(), [ref]1.1)
    }
    catch 
    {
        $var_tbkBdpResults.Text = "Failed to convert a texbox: $_"
        return $null
    }
    
    # get all the form units of measure
    try 
    {
        $bdpUnit = ($var_cbxBdpBdp.SelectedItem.Content.ToString().split(" "))[0]
        $bUnit = ($var_cbxBdpB.SelectedItem.Content.ToString().split(" "))[0]
        $rttUnit = ($var_cbxBdpRTT.SelectedItem.Content.ToString().split(" "))[0]
    }
    catch 
    {
        $var_tbkBdpResults.Text = "Failed to convert a unit: $_"
        return $null
    }

    # convert units to Byte (BDP), bit (B), and second (RTT)
    if ($BDP -gt 0)
    {
        $orgBDP = $BDP
        $BDP = Convert-Byte2Byte $BDP $bdpUnit
    }

    if ($B -gt 0)
    {
        $orgB = $B
        $B = Convert-Bit2Bit $B $bUnit
    }

    if ($RTT -gt 0)
    {
        $orgRTT = $RTT
        $RTT = Convert-Sec2Sec $RTT $rttUnit
    }

    # perform the actual work
    $result = Find-BPD $BDP $B $RTT

    if ($result)
    {
        $output = ""

        if ($BDP -gt 0) { $output += "BDP:     $orgBDP $bdpUnit ($BDP B)`n" } else { $r = "BDP" }
        if ($B -gt 0) { $output +=   "B:       $orgB $bUnit ($B b)`n" } else { $r = "B" }
        if ($RTT -gt 0) { $output += "RTT:     $orgRTT $rttUnit ($RTT s)`n" } else { $r = "RTT" }

        switch ($r)
        {
            "BDP" 
            {
                # results will be in Bytes, convert to selected unit
                switch ($bdpUnit)
                {
                    "B"     { $result = $result }
                    "KB"    { $result = [math]::Round($result / 1KB, 0) }
                    "MB"    { $result = [math]::Round($result / 1MB, 0) }
                    "GB"    { $result = [math]::Round($result / 1GB, 0) }
                    "TB"    { $result = [math]::Round($result / 1TB, 0) }
                    "PB"    { $result = [math]::Round($result / 1PB, 0) }
                    "EB"    { $result = [math]::Round($result / (1PB * 1KB), 0) }
                    default { 
                        $var_tbkBdpResults.Text = "Unknown unit: $bdpUnit"
                        return $null
                    }
                }

                $output += "`nBDP:     $result $bdpUnit"
            }

            "B"   
            {
                # results will be in bps, convert to selected unit
                switch ($bUnit)
                {
                    "bps"     { $result = $result }
                    "Kbps"    { $result = [math]::Round($result / [math]::Pow(10,3), 2) }
                    "Mbps"    { $result = [math]::Round($result / [math]::Pow(10,6), 2) }
                    "Gbps"    { $result = [math]::Round($result / [math]::Pow(10,9), 2) }
                    "Tbps"    { $result = [math]::Round($result / [math]::Pow(10,12), 2) }
                    "Pbps"    { $result = [math]::Round($result / [math]::Pow(10,15), 2) }
                    "Ebps"    { $result = [math]::Round($result / [math]::Pow(10,18), 2) }
                    default { 
                        $var_tbkBdpResults.Text = "Unknown unit: $bUnit"
                        return $null
                    }
                }

                $output += "`nB:       $result $bUnit"
            }
            "RTT" 
            {
                # results will be in bps, convert to selected unit
                switch ($rttUnit)
                {
                    "s"     { $result = $result }
                    "ms"    { $result = [math]::Round($result / [math]::Pow(10,-3), 2) }
                    "µs"    { $result = [math]::Round($result / [math]::Pow(10,-6), 2) }
                    "ns"    { $result = [math]::Round($result / [math]::Pow(10,-9), 2) }
                    default { 
                        $var_tbkBdpResults.Text = "Unknown unit: $rttUnit"
                        return $null
                    }
                }

                $output += "`nRTT:     $result $rttUnit"
            }
            default 
            { 
                $var_tbkBdpResults.Text = "Overload: This form only accepts 2 values and 3 were entered. Press Clear and try again."
                return $null
            }
        }

        $var_tbkBdpResults.Text = $output
    }
    else
    {
        return $null
    }
})


### BPD tab - BDP textbox handlers ###

$var_tbxBdpBdp.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotBdpBdp" $e

    $e.Handled = $result
})

$var_tbxBdpBdp.Add_KeyUp({
    if ($var_tbxBdpBdp.Text.ToCharArray() -notcontains ".")
    {
        $script:dotBdpBdp = $false
    }
})

### BPD tab - B textbox handlers ###

$var_tbxBdpB.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotBdpB" $e

    $e.Handled = $result
})

$var_tbxBdpB.Add_KeyUp({
    if ($var_tbxBdpB.Text.ToCharArray() -notcontains ".")
    {
        $script:dotBdpB = $false
    }
})

### BPD tab - RTT textbox handlers ###

$var_tbxBdpRTT.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotBdpRtt" $e

    $e.Handled = $result
})

$var_tbxBdpRTT.Add_KeyUp({
    if ($var_tbxBdpRTT.Text.ToCharArray() -notcontains ".")
    {
        $script:dotBdpRTT = $false
    }
})

#endregion


#### Mathis Tab ####
#region

$var_btnMathisCls.Add_Click({
    #$var_tbkBdpResults.Clear()
    $var_tbxMathisMss.Clear()
    $var_tbxMathisRtt.Clear()
    $var_tbxMathisP.Clear()

    [bool]$script:dotMathisMss = $false
    [bool]$script:dotMathisRtt = $false
    [bool]$script:dotMathisP = $false
})

$var_btnMathisCalc.Add_Click({
    # calculate max goodput
    # convert all form values to double
    try 
    {
        [decimal]$MSS = $var_tbxMathisMSS.Text
        [decimal]$RTT = $var_tbxMathisRTT.Text
        [decimal]$P = $var_tbxMathisP.Text
    }
    catch 
    {
        $var_tbkMathisResults.Text = "Failed to convert a texbox: $_"
        return $null
    }
    
    # get all the form units of measure
    try 
    {
        $rttUnit = ($var_cbxMathisRTT.SelectedItem.Content.ToString().split(" "))[0]
    }
    catch 
    {
        $var_tbkMathisResults.Text = "Failed to convert a unit: $_"
        return $null
    }

    if ($MSS -le 0 -or $RTT -le 0 -or $P -le 0)
    {
        $var_tbkMathisResults.Text = "All fields are required!"
        return $null
    }

    # convert RTT to seconds
    $orgRTT = $RTT
    $RTT = Convert-Sec2Sec $RTT $rttUnit

    # convert percent to decimal form
    $orgP = $P
    $P = $P / 100

    # perform the calculation
    $maxGput = (($MSS * 8) * [math]::sqrt(3/2)) / ($RTT * [math]::sqrt($P))

    # format maxGPut
    switch  ($maxGput)
    {
        {$_ -lt [math]::Pow(10,3)}
        {
            $gputUnit = "bps"
            $maxGput = [math]::Round($maxGput, 2)
            break
        }

        {$_ -lt [math]::Pow(10,6)}
        {
            $gputUnit = "Kbps"
            $maxGput = [math]::Round($maxGput / [math]::Pow(10,3), 2)
            break
        }

        {$_ -lt [math]::Pow(10,9)}
        {
            $gputUnit = "Mbps"
            $maxGput = [math]::Round($maxGput / [math]::Pow(10,6), 2)
            break
        }

        {$_ -lt [math]::Pow(10,12)}
        {
            $gputUnit = "Gbps"
            $maxGput = [math]::Round($maxGput / [math]::Pow(10,9), 2)
            break
        }

        {$_ -lt [math]::Pow(10,15)}
        {
            $gputUnit = "Tbps"
            $maxGput = [math]::Round($maxGput / [math]::Pow(10,12), 2)
            break
        }

        {$_ -lt (1PB * [math]::Pow(10,18))}
        {
            $gputUnit = "Pbps"
            $maxGput = [math]::Round($maxGput / [math]::Pow(10,15), 2)
            break
        }

        default
        {
            $gputUnit = "Ebps"
            $maxGput = [math]::Round($maxGput / (1PB * [math]::Pow(10,18)), 2)
            break
        }
    }

    # generate output
    $output = @"
Max Goodput < $maxGput $gputUnit
MSS:          $MSS B
RTT:          $orgRTT $rttUnit ($RTT s)
Loss:         $orgP% ($P)
"@

    $var_tbkMathisResults.Text = $output
})


### Mathis tab - MSS textbox handlers ###

$var_tbxMathisMss.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigi  $e

    $e.Handled = $result
})


### Mathis tab - RTT textbox handlers ###

$var_tbxMathisRtt.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotMathisRtt" $e

    $e.Handled = $result
})

$var_tbxMathisRtt.Add_KeyUp({
    if ($var_tbxMathisRtt.Text.ToCharArray() -notcontains ".")
    {
        $script:dotMathisRtt = $false
    }
})


### Mathis tab - P textbox handlers ###

$var_tbxMathisP.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotMathisP" $e

    $e.Handled = $result
})

$var_tbxMathisP.Add_KeyUp({
    if ($var_tbxMathisP.Text.ToCharArray() -notcontains ".")
    {
        $script:dotMathisP = $false
    }
})

#endregion


#### CONVERSION tab ####


### GB/s <-> Gbps ###
#region

$script:dotConvGB2GbpsLeft = $false
$script:dotConvGB2GbpsRight = $false

$var_tbxConvB2BLeft.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotConvGB2GbpsLeft" $e

    $e.Handled = $result
})

$var_tbxConvB2BLeft.Add_KeyUp({
    # read GB/s
    [decimal]$GBs = $var_tbxConvB2BLeft.Text
    [string]$GBsUnit = $var_cbxConvB2BLeft.SelectedItem.Content.split(" ")[0]

    #$output = "0: $GBs $GBsUnit = $Gbps $GbpsUnit`n"

    # convert to B/s
    $Gbps = Convert-Bs2bps $GBs $GBsUnit

    #$output += "1.5: $GBs $GBsUnit = $Gbps $GbpsUnit`n"

    # get the other side unit
    $GbpsUnit = $var_cbxConvB2BRight.SelectedItem.Content.split(" ")[0]

    #$output += "1: $GBs $GBsUnit = $Gbps $GbpsUnit`n"

    # convert bps units
    switch ($GbpsUnit) {
        "bps"     { $Gbps = $Gbps }
        "Kbps"    { $Gbps = ($Gbps / [math]::Pow(10,3)) }
        "Mbps"    { $Gbps = ($Gbps / [math]::Pow(10,6)) }
        "Gbps"    { $Gbps = ($Gbps / [math]::Pow(10,9)) }
        "Tbps"    { $Gbps = ($Gbps / [math]::Pow(10,12)) }
        "Pbps"    { $Gbps = ($Gbps / [math]::Pow(10,15)) }
        "Ebps"    { $Gbps = ($Gbps / [math]::Pow(10,18)) }
        default   { $Gbps = $null}
    }
    
    # set Gbps
    #$output += "2: $GBs $GBsUnit = $Gbps $GbpsUnit`n"
    #$var_tbkBdpResults.Text = $output
    $var_tbxConvB2BRight.Text = $Gbps
})

$var_cbxConvB2BLeft.Add_SelectionChanged({
    # clear results
    $var_tbxConvB2BLeft.Clear()
    $var_tbxConvB2BRight.Clear()

    $script:dotConvGB2GbpsLeft = $false
    $script:dotConvGB2GbpsRight = $false
})

$var_tbxConvB2BRight.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotConvGB2GbpsRight" $e

    $e.Handled = $result
})

$var_tbxConvB2BRight.Add_KeyUp({
    # read bps
    [decimal]$bps = $var_tbxConvB2BRight.Text
    [string]$bpsUnit = $var_cbxConvB2BRight.SelectedItem.Content.split(" ")[0]

    #$output = "0: $bs $bsUnit = $bps $bpsUnit`n"

    # convert to B/s
    $bs = Convert-bps2Bs $bps $bpsUnit

    #$output += "1.5: $bs $bsUnit = $bps $bpsUnit`n"

    # get the other side unit
    $bsUnit = $var_cbxConvB2BLeft.SelectedItem.Content.split(" ")[0]

    #$output += "1: $bs $bsUnit = $bps $bpsUnit`n"

    # convert bps units
    switch ($bsUnit) {
        "B/s"     { $bs = $bs }
        "KB/s"    { $bs = ($bs / [math]::Pow(10,3)) }
        "MB/s"    { $bs = ($bs / [math]::Pow(10,6)) }
        "GB/s"    { $bs = ($bs / [math]::Pow(10,9)) }
        "TB/s"    { $bs = ($bs / [math]::Pow(10,12)) }
        "PB/s"    { $bs = ($bs / [math]::Pow(10,15)) }
        "EB/s"    { $bs = ($bs / [math]::Pow(10,18)) }
        default   { $bs = $null}
    }
    
    # set Gbps
    #$output += "2: $bs $bsUnit = $bps $bpsUnit`n"
    #$var_tbkBdpResults.Text = $output
    $var_tbxConvB2BLeft.Text = $bs
})

$var_cbxConvB2BRight.Add_SelectionChanged({
    # clear results
    $var_tbxConvB2BLeft.Clear()
    $var_tbxConvB2BRight.Clear()

    $script:dotConvGB2GbpsLeft = $false
    $script:dotConvGB2GbpsRight = $false
})
#endregion

### Second <-> Second ###
#region
$script:dotConvS2SLeft = $false
$script:dotConvS2SRight = $false

$var_tbxConvSecLeft.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotConvS2SLeft" $e

    $e.Handled = $result
})

$var_tbxConvSecLeft.Add_KeyUp({
    Convert-LeftSec2RightSec
})

$var_cbxConvSecLeft.Add_SelectionChanged({
    # clear results
    $var_tbxConvSecLeft.Clear()
    $var_tbxConvSecRight.Clear()

    $script:dotConvS2SLeft = $false
    $script:dotConvS2SRight = $false
})

$var_tbxConvSecRight.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotConvS2SRight" $e

    $e.Handled = $result
})

$var_tbxConvSecRight.Add_KeyUp({
    Convert-RightSec2LeftSec
})

$var_cbxConvSecRight.Add_SelectionChanged({
    # clear results
    $var_tbxConvSecLeft.Clear()
    $var_tbxConvSecRight.Clear()

    $script:dotConvS2SLeft = $false
    $script:dotConvS2SRight = $false
})
#endregion

### Bytes <-> Bits ###
#region

[bool]$script:dotConvBLeft = $false

$var_tbxConvBLeft.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigiDot "script:dotConvBLeft" $e

    $e.Handled = $result
})

$var_tbxConvBLeft.Add_KeyUp({
    # get bytes
    [decimal]$byte = $var_tbxConvBLeft.Text
    [string]$byteUnit = $var_cbxConvBLeft.SelectedItem.Content.split(" ")[0]

    $output = "0: $byte $byteUnit = $bit $bitUnit`n"

    # total bytes
    switch ($byteUnit) {
        "b"  {$byte = $byte}
        "Kb" {$byte = $byte * [math]::Pow(10,3)}
        "Mb" {$byte = $byte * [math]::Pow(10,6)}
        "Gb" {$byte = $byte * [math]::Pow(10,9)}
        Default { return $null }
    }

    $output += "1: $byte $byteUnit = $bit $bitUnit`n"

    # get bit unit
    [string]$bitUnit = $var_cbxConvBRight.SelectedItem.Content.split(" ")[0]

    $output += "2: $byte $byteUnit = $bit $bitUnit`n"

    # convert, or I'll poke you with the soft cushion!
    switch ($bitUnit) {
        "b"  {$bit = (Convert-Byte2Bit $byte)}
        "Kb" {$bit = (Convert-Byte2Bit $byte) * [math]::Pow(10,-3)}
        "Mb" {$bit = (Convert-Byte2Bit $byte) * [math]::Pow(10,-6)}
        "Gb" {$bit = (Convert-Byte2Bit $byte) * [math]::Pow(10,-9)}
        Default { return $null }
    }

    $output += "3: $byte $byteUnit = $bit $bitUnit`n"
    $var_tbkBdpResults.Text = $output

    $var_tbxConvBRight.Text = $bit
})

$var_cbxConvBLeft.Add_SelectionChanged({
    $var_tbxConvBLeft.Clear()
    $var_tbxConvBRight.Clear()

    $script:dotConvBLeft = $false
})

## bit -> Byte ##
$var_tbxConvBRight.Add_PreviewKeyDown({
    $e = $args[1]

    $result = PreviewKeyDownDigi $e

    $e.Handled = $result
})

$var_tbxConvBRight.Add_KeyUp({
    # get bytes
    [decimal]$bit = $var_tbxConvBRight.Text
    [string]$bitUnit = $var_cbxConvBRight.SelectedItem.Content.split(" ")[0]

    $output = "0: $byte $byteUnit = $bit $bitUnit`n"

    # total bytes
    $bit = Convert-Bit2Bit $bit "$bitUnit`ps"

    $output += "1: $byte $byteUnit = $bit $bitUnit`n"

    # get bit unit
    [string]$byteUnit = $var_cbxConvBLeft.SelectedItem.Content.split(" ")[0]

    $output += "2: $byte $byteUnit = $bit $bitUnit`n"

    # convert, or I'll poke you with the soft cushion!
    switch ($byteUnit) {
        "b"  {$byte = (Convert-Bit2Byte $bit)}
        "Kb" {$byte = (Convert-Bit2Byte $bit) / [math]::Pow(10,3)}
        "Mb" {$byte = (Convert-Bit2Byte $bit) / [math]::Pow(10,6)}
        "Gb" {$byte = (Convert-Bit2Byte $bit) / [math]::Pow(10,9)}
        Default { return $null }
    }

    $output += "3: $byte $byteUnit = $bit $bitUnit`n"
    $var_tbkBdpResults.Text = $output

    $var_tbxConvBLeft.Text = $byte
})

$var_cbxConvBRight.Add_SelectionChanged({
    $var_tbxConvBLeft.Clear()
    $var_tbxConvBRight.Clear()

    $script:dotConvBLeft = $false
})

#endregion


### Reset Convserion Form ###

$var_btnConvRst.Add_Click({
    # byte <-> bit
    $var_tbxConvBLeft.Clear()
    $var_tbxConvBRight.Clear()

    $script:dotConvBLeft = $false

    $var_cbxConvBLeft.SelectedIndex = 0
    $var_cbxConvBRight.SelectedIndex = 0


    # sec <-> sec
    $var_tbxConvSecLeft.Clear()
    $var_tbxConvSecRight.Clear()

    $script:dotConvS2SLeft = $false
    $script:dotConvS2SRight = $false

    $var_cbxConvSecLeft.SelectedIndex = 2
    $var_cbxConvSecRight.SelectedIndex = 3

    # GB/s <-> Gbps
    $var_tbxConvB2BLeft.Clear()
    $var_tbxConvB2BRight.Clear()

    $script:dotConvGB2GbpsLeft = $false
    $script:dotConvGB2GbpsRight = $false

    $var_cbxConvB2BLeft.SelectedIndex = 3
    $var_cbxConvB2BRight.SelectedIndex = 3
    
})



##### show the UI #####
$window.TopMost = $true
$null = $window.ShowDialog()

##### clean up #####
$null = $window.Close()
$window = $null

Get-Variable -Name "var_*" -Scope Local | Remove-Variable -Force
