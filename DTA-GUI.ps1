Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ZipFileContent {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [Object]$Path,
        [Parameter(DontShow)]
        [Int]$NestedLevel = 0
    )
    begin {
        $NestedLevel++
    }

    process {
        try {
            $ZipFile = if (-not ($NestedLevel - 1)) {
                [System.IO.Compression.ZipFile]::OpenRead($Path)
            }
            else {
                [System.IO.Compression.ZipArchive]::New($Path.Open())
            }
            foreach ($Entry in $ZipFile.Entries) {
                # Output entries, skipping folders
                if ($Entry.Name -ne '') {
                    [PSCustomObject]@{
                        Level     = $NestedLevel
                        Container = $(if ([string]::IsNullOrEmpty($Path.Name)) { (Get-ItemProperty $Path).Name } else { $Path.Name })
                        FullName  = $Entry.FullName
                        Size      = $entry.Length
                    }
                    # Check for nested zip
                    if ([System.IO.Path]::GetExtension($Entry) -eq '.zip') {
                        Get-ZipFileContent -Path $entry -NestedLevel $NestedLevel
                    }
                }
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
        finally {
            if ($null -ne $zip) {
                $ZipFile.Dispose()
            }
        }
    }

    end {}
}

function Get-TarFileContent {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [Object]$Path
    )
    begin {}

    process {
        $Files = tar -tvf "$Path"
        foreach ($File in $Files) {
            $SplitFile = $File -split '\s+'
            [PSCustomObject]@{
                Level     = 1
                Container = Split-Path $Path -Leaf
                FullName  = $SplitFile[-1]
                Size      = $SplitFile[4]
            }
        }
    }

    end {}

}

function Write-DtaFileLog {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet("L2H", "H2H", "H2L")]
        [string]$TransferType,
        [Parameter()]
        [string]$NetworkSource,
        [Parameter()]
        [string]$NetworkDestination,
        [Parameter()]
        [datetime]$TransferDate,
        [Parameter()]
        [string]$Username,
        [Parameter()]
        [string]$DataTransferFolder,
        [Parameter()]
        [string]$LogOutputFolder,
        [Parameter()]
        [string]$OutputDateFormat = 'yyyyMMdd',
        [Parameter()]
        [string[]]$OutputFormatToken,
        [Parameter()]
        [string]$OutputFormatDelimiter
    )

    begin {}

    process {
        $Date = Get-Date $TransferDate -Format "$OutputDateFormat"
        $Network = "$NetworkSource-$NetworkDestination"
        foreach ($Token in $OutputFormatToken) {
            $OutputName += "$((Get-Variable -Name $Token).Value)"
            $OutputName += $OutputFormatDelimiter
        }

        # Test if the output file already exists; increment if it does.
        $TransferCount = 0
        Do {
            $TransferCount++
            $OutputNameNumbered = "$OutputName$('{0:d3}' -f $TransferCount)"
            $OutputPath = Join-Path -Path "$LogOutputFolder" -ChildPath "$OutputNameNumbered.csv"
        }
        While (Test-Path "$OutputPath")

        $Files = Get-ChildItem -Path $DataTransferFolder -Recurse -File
        $Files | Add-Member -MemberType NoteProperty -Name 'Level' -Value '0'
        $Files | Add-Member -MemberType NoteProperty -Name 'Container' -Value ''
        $Files | Select-Object -Property Level, Container, FullName, @{Name = 'Size'; Expression = { $_.Length } } | Export-Csv -Path "$OutputPath" -NoClobber -NoTypeInformation

        $ZipFiles = $Files | Where-Object { $_.Extension -eq '.zip' }
        if ($ZipFiles) {
            foreach ($ZipFile in $ZipFiles) {
                Get-ZipFileContent -Path "$($ZipFile.FullName)" | Export-Csv -Path "$OutputPath" -Append -NoTypeInformation
            }
        }
        else {
            Write-Verbose "No zip files found."
        }

        $TarFiles = $Files | Where-Object { ($_.Extension -eq '.tar') -or ($_.Extension -eq '.gz') -or ($_.Extension -eq '.tgz') }
        if ($TarFiles) {
            foreach ($TarFile in $TarFiles) {
                Get-TarFileContent -Path "$($TarFile.FullName)" | Export-Csv -Path "$OutputPath" -Append -NoTypeInformation
            }
        }
        else {
            Write-Verbose "No tar/gz files found."
        }

        @{
            OutputPath = $OutputPath
            OutputFile = "$OutputNameNumbered.csv"
            FileCount  = $Files.Count
            Success    = Test-Path -Path "$OutputPath"
        }
    }

    end {}
}

function Write-DtaTransferLog {
    [CmdletBinding()]
    param (
        [Parameter()]
        [datetime]$TransferDate,
        [Parameter()]
        [string]$Username,
        [Parameter()]
        [string]$ComputerName,
        [Parameter()]
        [string]$MediaType,
        [Parameter()]
        [string]$MediaID,
        [Parameter()]
        [string]$TransferType,
        [Parameter()]
        [string]$Source,
        [Parameter()]
        [string]$Destination,
        [Parameter()]
        [int]$FileCount,
        [Parameter()]
        [string]$FileLog,
        [Parameter()]
        [string]$TransferLogPath,
        [Parameter()]
        [string]$TransferLogName
    )

    begin {}

    process {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $OutputPath = Join-Path -Path $TransferLogPath -ChildPath $TransferLogName

        $Entry = [PSCustomObject]@{
            Timestamp       = $Timestamp
            'Transfer Date' = $(Get-Date $TransferDate -Format 'yyyy-MM-dd')
            Username        = $Username
            ComputerName    = $ComputerName
            MediaType       = $MediaType
            MediaID         = $MediaID
            TransferType    = $TransferType
            Source          = $Source
            Destination     = $Destination
            'File Count'    = $FileCount
            'File Log'      = $FileLog
        }

        $Entry | Export-Csv -Path "$OutputPath" -Append -NoTypeInformation
    }

    end {}
}

#region Main Window
$WindowXamlFile = "$PSScriptRoot\Resources\MainWindow.xaml"

$WindowInputXML = Get-Content $WindowXamlFile -Raw
$WindowInputXML = $WindowInputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[xml]$WindowXaml = $WindowInputXML

$Reader = (New-Object System.Xml.XmlNodeReader $WindowXaml)
try {
    $Window = [Windows.Markup.XamlReader]::Load( $Reader )
}
catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names. Variable will be named as 'var_<control name>'
$WindowXaml.SelectNodes("//*[@Name]") | ForEach-Object {
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $Window.FindName($_.Name) -ErrorAction Stop
    }
    catch {
        throw
    }
}

# Debug
#Get-Variable var_*

# Windows Icon
$Window.add_Loaded({
        $Window.Icon = "$PSScriptRoot\Resources\Logo.bmp"
    })
#endregion Main Window

# Read in configuration files
$Config = Import-PowerShellDataFile -Path "$PSScriptRoot\Config\config.psd1"

# Set default configuration options
$var_txtbx_Username.Text = $env:USERNAME
$var_txtbx_Computername.Text = $env:COMPUTERNAME
$var_dtpkr_TransferDate.Text = Get-Date -Format "M/d/yyyy"
$var_cmbx_Source.ItemsSource = $Config.Data.NetworkList
$var_cmbx_Destination.ItemsSource = $Config.Data.NetworkList
$var_cmbx_MediaType.ItemsSource = $Config.Data.MediaType
$var_cmbx_MediaID.ItemsSource = $Config.Data.MediaID
$var_cmbx_TransferType.ItemsSource = 'Low to High', 'High to High', 'High to Low'
$var_txtbx_LogOutputFolder.Text = $Config.Output.LogFolder

# Blackout future dates for the Transfer date
$BlackoutDates = $var_dtpkr_TransferDate.BlackoutDates
$CalendarDateRange = New-Object System.Windows.Controls.CalendarDateRange
$CalendarDateRange.Start = (Get-Date).AddDays(1)
$CalendarDateRange.End = [DateTime]::MaxValue
$BlackoutDates.Add($CalendarDateRange)


$var_btn_DataTransferFolder.Add_Click({
        $Browser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{Description = "Select the folder containing the files to be transferred." }
        $null = $Browser.ShowDialog()
        $var_txtbx_DataTransferFolder.Text = $Browser.SelectedPath
    })

$var_btn_LogOutputFolder.Add_Click({
        $Browser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{Description = "Select the folder containing the files to be transferred." }
        $null = $Browser.ShowDialog()
        $var_txtbx_LogOutputFolder.Text = $Browser.SelectedPath
    })

# Submit button
$var_btn_Submit.Add_Click({
        $Username = $var_txtbx_Username.Text
        $ComputerName = $var_txtbx_Computername.Text
        $MediaType = $var_cmbx_MediaType.Text
        $MediaID = $var_cmbx_MediaID.Text
        $TransferType = $var_cmbx_TransferType.Text
        $NetworkSource = $var_cmbx_Source.Text
        $NetworkDestination = $var_cmbx_Destination.Text
        $TransferDate = $var_dtpkr_TransferDate.Text
        $DataTransferFolder = $var_txtbx_DataTransferFolder.Text
        $LogOutputFolder = $var_txtbx_LogOutputFolder.Text

        # Validation that all values have been set
        $var_lbl_MissingRequired.Visibility = 'Hidden'
        if ([string]::IsNullOrEmpty($MediaType)) {
            $var_lbl_MediaType.Foreground = 'Red'
            $ValidationFailure = $true
        }
        else {
            $var_lbl_MediaType.Foreground = 'Black'
        }

        if ([string]::IsNullOrEmpty($MediaID)) {
            $var_lbl_MediaID.Foreground = 'Red'
            $ValidationFailure = $true
        }
        else {
            $var_lbl_MediaID.Foreground = 'Black'
        }

        if ([string]::IsNullOrEmpty($TransferType)) {
            $var_lbl_TransferType.Foreground = 'Red'
            $ValidationFailure = $true
        }
        else {
            $var_lbl_TransferType.Foreground = 'Black'
        }

        if ([string]::IsNullOrEmpty($NetworkSource)) {
            $var_lbl_Source.Foreground = 'Red'
            $ValidationFailure = $true
        }
        else {
            $var_lbl_Source.Foreground = 'Black'
        }

        if ([string]::IsNullOrEmpty($NetworkDestination)) {
            $var_lbl_Destination.Foreground = 'Red'
            $ValidationFailure = $true
        }
        else {
            $var_lbl_Destination.Foreground = 'Black'
        }

        if ((! [string]::IsNullOrEmpty($NetworkSource)) -and (! [string]::IsNullOrEmpty($NetworkDestination)) -and ($NetworkSource -eq $NetworkDestination)) {
            $var_lbl_NetworkNotMatchRequired.Visibility = 'Visible'
            $var_lbl_Source.Foreground = 'Red'
            $var_lbl_Destination.Foreground = 'Red'

            $ValidationFailure = $true
        }
        else {
            $var_lbl_NetworkNotMatchRequired.Visibility = 'Hidden'
        }

        if ([string]::IsNullOrEmpty($TransferDate)) {
            $var_lbl_Date.Foreground = 'Red'
            $ValidationFailure = $true
        }
        else {
            $var_lbl_Date.Foreground = 'Black'
        }

        if ([string]::IsNullOrEmpty($DataTransferFolder)) {
            $var_lbl_DataTransferFolder.Foreground = 'Red'
            $ValidationFailure = $true
        }
        elseif (! (Test-Path "$DataTransferFolder")) {
            $var_lbl_DataTransferFolder.Foreground = 'Red'
            $var_lbl_DataTransferFolderExistsRequired.Visibility = 'Visible'
            $ValidationFailure = $true
        }
        else {
            $var_lbl_DataTransferFolder.Foreground = 'Black'
            $var_lbl_DataTransferFolderExistsRequired.Visibility = 'Hidden'
        }

        if ($ValidationFailure) {
            $var_lbl_MissingRequired.Visibility = 'Visible'
            return
        }

        $TransferType = switch ($TransferType) {
            "Low to High" { "L2H" }
            "High to High" { "H2H" }
            "High to Low" { "H2L" }
        }

        if ($Config.Output.YearSubFolder) {
            $Year = Get-Date -Format 'yyyy'
            $LogOutputFolderBase = Join-Path -Path $LogOutputFolder -ChildPath $Year
            $TransferLogName = "$($Config.Output.TransferLogName)_$Year.csv"
            if (! (Test-Path $LogOutputFolderBase)) {
                New-Item -Path $LogOutputFolderBase -ItemType Directory
            }
        }
        else {
            $TransferLogName = "$($Config.Output.TransferLogName)`.csv"
        }

        $DTAFileParams = @{
            Username              = $Username
            TransferType          = $TransferType
            NetworkSource         = $NetworkSource
            NetworkDestination    = $NetworkDestination
            TransferDate          = $TransferDate
            DataTransferFolder    = $DataTransferFolder
            LogOutputFolder       = $LogOutputFolderBase
            OutputDateFormat      = $Config.Output.FileLog.DateFormat
            OutputFormatToken     = $Config.Output.FileLog.Order
            OutputFormatDelimiter = $Config.Output.FileLog.Delimiter
        }

        $Result = Write-DtaFileLog @DTAFileParams

        if ($Result.Success -eq $true) {
            Invoke-Item $Result.OutputPath

            $DTALogParams = @{
                TransferDate    = $TransferDate
                Username        = $Username
                ComputerName    = $ComputerName
                MediaType       = $MediaType
                MediaID         = $MediaID
                TransferType    = $TransferType
                Source          = $NetworkSource
                Destination     = $NetworkDestination
                TransferLogPath = $LogOutputFolder
                TransferLogName = $TransferLogName
                FileCount       = $Result.FileCount
                FileLog         = $Result.OutputFile
            }

            Write-DtaTransferLog @DTALogParams
        }
    })

[void]$Window.ShowDialog()