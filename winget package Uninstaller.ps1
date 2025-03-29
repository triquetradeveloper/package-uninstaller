Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Check if running as administrator; if not, restart with elevated privileges (this triggers the UAC prompt)
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ---------------- Main Program (runs only if admin) ----------------

# Create the main form with dark styling and a professional look
$form = New-Object System.Windows.Forms.Form
$form.Text = "Package Uninstaller"
$form.Size = New-Object System.Drawing.Size(900, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(45,45,48)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Create an automatic search bar for filtering packages
$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.Location = New-Object System.Drawing.Point(10, 10)
$searchBox.Size = New-Object System.Drawing.Size(880, 30)
$searchBox.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$searchBox.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($searchBox) | Out-Null

# Create a DataGridView to display installed package details
$dataGridView = New-Object System.Windows.Forms.DataGridView
$dataGridView.Location = New-Object System.Drawing.Point(10, 50)
$dataGridView.Size = New-Object System.Drawing.Size(880, 600)
$dataGridView.BackgroundColor = [System.Drawing.Color]::FromArgb(30,30,30)
$dataGridView.ForeColor = [System.Drawing.Color]::White
$dataGridView.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(63,63,70)
$dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$dataGridView.EnableHeadersVisualStyles = $false
$dataGridView.RowHeadersVisible = $false
$dataGridView.GridColor = [System.Drawing.Color]::FromArgb(63,63,70)
$dataGridView.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
$dataGridView.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$dataGridView.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(63,63,70)
$dataGridView.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$dataGridView.AllowUserToAddRows = $false
$dataGridView.SelectionMode = 'FullRowSelect'
$form.Controls.Add($dataGridView) | Out-Null

# Add a checkbox column for selection
$chkColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$chkColumn.HeaderText = "Select"
$chkColumn.Width = 50
$dataGridView.Columns.Add($chkColumn) | Out-Null

# Add a text column for Package Name
$nameColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$nameColumn.HeaderText = "Name"
$nameColumn.Width = 300
$dataGridView.Columns.Add($nameColumn) | Out-Null

# Add a text column for Version
$versionColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$versionColumn.HeaderText = "Version"
$versionColumn.Width = 150
$dataGridView.Columns.Add($versionColumn) | Out-Null

# Add a text column for Publisher
$publisherColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$publisherColumn.HeaderText = "Publisher"
$publisherColumn.Width = 200
$dataGridView.Columns.Add($publisherColumn) | Out-Null

# Add a text column for Package Type
$typeColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$typeColumn.HeaderText = "Type"
$typeColumn.Width = 100
$dataGridView.Columns.Add($typeColumn) | Out-Null

# Create a Button to uninstall selected packages
$buttonUninstall = New-Object System.Windows.Forms.Button
$buttonUninstall.Text = "Uninstall Selected"
$buttonUninstall.Location = New-Object System.Drawing.Point(10, 660)
$buttonUninstall.Size = New-Object System.Drawing.Size(150, 30)
$buttonUninstall.BackColor = [System.Drawing.Color]::FromArgb(63,63,70)
$buttonUninstall.ForeColor = [System.Drawing.Color]::White
$buttonUninstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($buttonUninstall) | Out-Null

# Create a Refresh button to reload packages
$buttonRefresh = New-Object System.Windows.Forms.Button
$buttonRefresh.Text = "Refresh"
$buttonRefresh.Location = New-Object System.Drawing.Point(170, 660)
$buttonRefresh.Size = New-Object System.Drawing.Size(150, 30)
$buttonRefresh.BackColor = [System.Drawing.Color]::FromArgb(63,63,70)
$buttonRefresh.ForeColor = [System.Drawing.Color]::White
$buttonRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($buttonRefresh) | Out-Null
$buttonRefresh.Add_Click({ Load-Packages })

# Create a status label for notifications
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.Location = New-Object System.Drawing.Point(10, 700)
$statusLabel.Size = New-Object System.Drawing.Size(880, 20)
$statusLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($statusLabel) | Out-Null

# Global variable to store all package objects (combined list)
$global:allPackagesList = @()

# Function to load packages from multiple sources
function Load-Packages {
    try {
        $combinedPackages = @()

        # 1. Get UWP/AppX packages
        $appxPackages = Get-AppxPackage -AllUsers | ForEach-Object {
            [PSCustomObject]@{
                Name            = if ($_.Name) { $_.Name } else { "N/A" }
                Version         = if ($_.Version) { $_.Version.ToString() } else { "N/A" }
                Publisher       = if ($_.Publisher) { $_.Publisher } else { "N/A" }
                Type            = "AppX"
                UninstallString = $null
                ProviderName    = $null
                Object          = $_
            }
        }
        $combinedPackages += $appxPackages

        # 2. Get Win32/installed packages from registry
        $win32Paths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $win32Packages = foreach ($path in $win32Paths) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            ForEach-Object {
                [PSCustomObject]@{
                    Name            = if ($_.DisplayName) { $_.DisplayName } else { "N/A" }
                    Version         = if ($_.DisplayVersion) { $_.DisplayVersion } else { "N/A" }
                    Publisher       = if ($_.Publisher) { $_.Publisher } else { "N/A" }
                    Type            = "Win32"
                    UninstallString = $_.UninstallString
                    ProviderName    = $null
                    Object          = $_
                }
            }
        }
        $combinedPackages += $win32Packages

        # 3. Get packages via PackageManagement (if available)
        $pkgMgmt = Get-Package -ErrorAction SilentlyContinue
        if ($pkgMgmt) {
            $pkgMgmtPackages = $pkgMgmt | ForEach-Object {
                [PSCustomObject]@{
                    Name            = if ($_.Name) { $_.Name } else { "N/A" }
                    Version         = if ($_.Version) { $_.Version.ToString() } else { "N/A" }
                    Publisher       = if ($_.PSObject.Properties['Publisher'] -and $_.Publisher) { $_.Publisher } else { "N/A" }
                    Type            = "PackageMgmt"
                    UninstallString = $null
                    ProviderName    = $_.ProviderName
                    Object          = $_
                }
            }
            $combinedPackages += $pkgMgmtPackages
        }

        $global:allPackagesList = $combinedPackages
        Filter-Packages
    }
    catch {
        $statusLabel.Text = ("Error retrieving packages: {0}" -f $_.Exception.Message)
    }
}

# Function to filter packages based on search input and update the DataGridView
function Filter-Packages {
    $dataGridView.Rows.Clear() | Out-Null
    $searchTerm = $searchBox.Text.Trim()
    $filtered = $global:allPackagesList
    if (-not [string]::IsNullOrEmpty($searchTerm)) {
        $filtered = $filtered | Where-Object { $_.Name -like "*$searchTerm*" }
    }
    foreach ($pkg in $filtered) {
        $rowIndex = $dataGridView.Rows.Add()
        $row = $dataGridView.Rows[$rowIndex]
        $row.Cells[0].Value = $false  # Checkbox unchecked by default
        $row.Cells[1].Value = $pkg.Name
        $row.Cells[2].Value = $pkg.Version
        $row.Cells[3].Value = $pkg.Publisher
        $row.Cells[4].Value = $pkg.Type
        # Store the package object in the row's Tag property for later use
        $row.Tag = $pkg
    }
}

# Load packages when the form starts
Load-Packages

# Automatic filtering as the user types in the search box
$searchBox.Add_TextChanged({ Filter-Packages })

# Uninstall event: uninstall all packages that are checked
$buttonUninstall.Add_Click({
    $rows = $dataGridView.Rows
    $foundAny = $false
    foreach ($row in $rows) {
        if ($row.Cells[0].Value -eq $true) {
            $foundAny = $true
            $pkg = $row.Tag
            if ($pkg.Type -eq "AppX") {
                try {
                    $apps = Get-AppxPackage -AllUsers | Where-Object { $_.PackageFullName -eq $pkg.Object.PackageFullName }
                    if ($apps) {
                        foreach ($app in $apps) {
                            Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction SilentlyContinue | Out-Null
                        }
                        $statusLabel.Text = "Uninstalled: $($pkg.Name)"
                    }
                    else {
                        $statusLabel.Text = "Package not found: $($pkg.Name)"
                    }
                }
                catch {
                    $statusLabel.Text = ("Error uninstalling {0}: {1}" -f $pkg.Name, $_.Exception.Message)
                }
            }
            elseif ($pkg.Type -eq "Win32") {
                $uninstallString = $pkg.UninstallString
                if ($uninstallString) {
                    try {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallString" -Verb RunAs -Wait
                        $statusLabel.Text = "Uninstalled: $($pkg.Name)"
                    }
                    catch {
                        $statusLabel.Text = ("Error uninstalling {0}: {1}" -f $pkg.Name, $_.Exception.Message)
                    }
                }
                else {
                    $statusLabel.Text = "No uninstall command found for: $($pkg.Name)"
                }
            }
            elseif ($pkg.Type -eq "PackageMgmt") {
                try {
                    Uninstall-Package -Name $pkg.Name -ProviderName $pkg.ProviderName -Force -Confirm:$false -ErrorAction Stop
                    $statusLabel.Text = "Uninstalled: $($pkg.Name)"
                }
                catch {
                    $statusLabel.Text = ("Error uninstalling {0}: {1}" -f $pkg.Name, $_.Exception.Message)
                }
            }
        }
    }
    if (-not $foundAny) {
        $statusLabel.Text = "No package selected for uninstallation."
    }
    # Refresh the package list after uninstallation
    Load-Packages
})

# Display the main form (in the admin process)
[void] $form.ShowDialog()
