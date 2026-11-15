# ISO-8601 timestamp (file created): 2026-11-15T01:28:16Z
# ==============================================================================
# create-windows-vm.ps1 - create a Hyper-V VM to host wa2dc-unified
# Version: 1.0.0
#
# Version history:
#   1.0.0  2026-11-15T01:28:16Z  Initial release (Generation 2 VM, Secure Boot,
#                                vTPM for Windows 11 guests, Linux-guest option).
#
# Run from an elevated PowerShell on a Windows 10/11 Pro or Windows Server host:
#   .\deploy\windows\create-windows-vm_v1.0.0_<timestamp>.ps1 -IsoPath C:\ISO\Win11_24H2_x64.iso
#   .\deploy\windows\create-windows-vm_v1.0.0_<timestamp>.ps1 -IsoPath C:\ISO\ubuntu-24.04-live-server-amd64.iso -Guest Linux
# Parameters:
#   -IsoPath   installation ISO for the guest operating system (required)
#   -Guest     Windows (default) or Linux - selects the Secure Boot template and vTPM
#   -Name      VM name (default: wa2dc)
#   -Cpus / -MemoryGB / -DiskGB   VM size (default: 2 / 4 / 64; Windows 11 needs >= 4 GB and >= 64 GB)
#   -VmRoot    folder for the VM's files (default: C:\HyperV)
# ==============================================================================
[CmdletBinding(SupportsShouldProcess = $true)]   # enables -WhatIf as a dry-run
param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [ValidateSet('Windows', 'Linux')][string]$Guest = 'Windows',
    [string]$Name = 'wa2dc',
    [int]$Cpus = 2,
    [int]$MemoryGB = 4,
    [int]$DiskGB = 64,
    [string]$VmRoot = 'C:\HyperV'
)

$ErrorActionPreference = 'Stop'                  # treat every error as fatal
Set-StrictMode -Version Latest                   # catch typos in variable names
function Write-Step([string]$Message) { Write-Host "[create-windows-vm] $Message" -ForegroundColor Cyan }

# --- pre-flight checks ----------------------------------------------------------
if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }
if (-not (Get-Command New-VM -ErrorAction SilentlyContinue)) {
    # Hyper-V is an optional Windows feature; enabling it needs one reboot.
    throw ('Hyper-V is not enabled. Run:  Enable-WindowsOptionalFeature -Online -FeatureName ' +
           'Microsoft-Hyper-V -All   (Windows Server: Install-WindowsFeature Hyper-V ' +
           '-IncludeManagementTools), reboot, then run this script again.')
}
if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { throw "A VM named '$Name' already exists." }

# --- networking: "Default Switch" (NAT + DHCP) exists on client Windows ---------
$Switch = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue
if (-not $Switch) {
    # Windows Server has no Default Switch: bridge to the first connected physical adapter instead.
    $Adapter = Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Select-Object -First 1
    if (-not $Adapter) { throw 'No connected physical network adapter found for an external switch.' }
    Write-Step "Creating external switch 'wa2dc-external' on $($Adapter.Name)"
    if ($PSCmdlet.ShouldProcess('wa2dc-external', 'New-VMSwitch')) {
        $Switch = New-VMSwitch -Name 'wa2dc-external' -NetAdapterName $Adapter.Name -AllowManagementOS $true
    }
}
$SwitchName = if ($Switch) { $Switch.Name } else { 'wa2dc-external' }

# --- create the VM --------------------------------------------------------------
$VmPath  = Join-Path $VmRoot $Name               # configuration files live here
$VhdPath = Join-Path $VmPath "$Name.vhdx"        # dynamically expanding system disk
if ($PSCmdlet.ShouldProcess($Name, 'Create Hyper-V VM')) {
    Write-Step "Creating Generation 2 VM '$Name' ($Cpus vCPU, $MemoryGB GB RAM, $DiskGB GB disk)"
    New-VM -Name $Name -Generation 2 -Path $VmRoot -MemoryStartupBytes ($MemoryGB * 1GB) `
        -NewVHDPath $VhdPath -NewVHDSizeBytes ($DiskGB * 1GB) -SwitchName $SwitchName | Out-Null
    Set-VMProcessor -VMName $Name -Count $Cpus
    # A bridge is a long-running service: fixed memory avoids ballooning pauses.
    Set-VMMemory -VMName $Name -DynamicMemoryEnabled $false
    # Start with the host and shut down cleanly with it, so the bridge survives host reboots.
    Set-VM -Name $Name -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticCheckpointsEnabled $false

    if ($Guest -eq 'Windows') {
        # Windows 11 requires Secure Boot and a TPM 2.0; give the VM a virtual TPM.
        Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate 'MicrosoftWindows'
        Set-VMKeyProtector -VMName $Name -NewLocalKeyProtector
        Enable-VMTPM -VMName $Name
    } else {
        # Linux distributions are signed with the Microsoft UEFI CA, not the Windows production key.
        Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
    }

    # Attach the installer ISO and boot from it first.
    $Dvd = Add-VMDvdDrive -VMName $Name -Path $IsoPath -Passthru
    Set-VMFirmware -VMName $Name -FirstBootDevice $Dvd

    Start-VM -Name $Name
    Write-Step 'VM started. Opening the console to complete operating-system setup.'
    vmconnect.exe localhost $Name                # press a key quickly to boot from the DVD
}

# --- next steps -----------------------------------------------------------------
Write-Step 'After the guest OS is installed:'
if ($Guest -eq 'Windows') {
    Write-Step '  1. In the guest, extract the release ZIP (or git clone) to C:\wa2dc-unified'
    Write-Step '  2. Elevated PowerShell: Set-ExecutionPolicy -Scope Process Bypass -Force'
    Write-Step '  3. .\deploy\windows\install-windows_v1.0.0_<timestamp>.ps1 -Bridge main'
} else {
    Write-Step '  1. In the guest: sudo git clone <your repo URL> /opt/wa2dc-unified'
    Write-Step '  2. cd /opt/wa2dc-unified && sudo bash deploy/linux/install-linux_v1.0.0_*.sh --bridge main'
}
Write-Step "Remove the ISO afterwards:  Get-VMDvdDrive -VMName $Name | Remove-VMDvdDrive"
# ISO-8601 timestamp (end of file): 2026-11-15T01:28:16Z
