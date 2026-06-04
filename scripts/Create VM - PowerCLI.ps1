# Project Fortress - Windows Server 2019 Base VM Provisioning
# Purpose: Create a baseline Windows Server 2019 VM for template preparation.
# Scope: Lab automation only. Certificate validation is relaxed for the internal vCenter lab environment.

# 1. Lab-only certificate handling for self-signed vCenter certificate
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# 2. Connect to vCenter
$VIServer = "vcenter.home"
Connect-VIServer -Server $VIServer

# 3. Define base VM variables
$VMName    = "Win2019-Template-Base"
$VMHostIP  = "192.168.0.11"
$Datastore = "ds-local-nvme-01"
$PortGroupName = "VM Network"

# 4. Resolve vSphere inventory objects
$TargetHost = Get-VMHost -Name $VMHostIP
$TargetDatastore = Get-Datastore -Name $Datastore
$TargetPortGroup = Get-VirtualPortGroup -VMHost $TargetHost -Name $PortGroupName

# 5. Pre-flight duplicate check
if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    throw "A VM named '$VMName' already exists. Rename or remove the existing VM before continuing."
}

# 6. Provision the Windows Server 2019 base VM
Write-Host "Provisioning $VMName..." -ForegroundColor Cyan

$VM = New-VM `
    -Name $VMName `
    -VMHost $TargetHost `
    -Datastore $TargetDatastore `
    -NumCPU 2 `
    -MemoryGB 4 `
    -DiskGB 60 `
    -DiskStorageFormat Thin `
    -Portgroup $TargetPortGroup `
    -GuestId "windows2019srv_64Guest" `
    -Notes "Project Fortress Windows Server 2019 base VM for template preparation."

# 7. Confirm network adapter type is VMXNET3
Write-Host "Configuring network adapter as VMXNET3..." -ForegroundColor Cyan

$VM | Get-NetworkAdapter | Set-NetworkAdapter -Type Vmxnet3 -Confirm:$false | Out-Null

# 8. Report completion
Write-Host "Base VM provisioned successfully." -ForegroundColor Green
Write-Host "Next steps: Attach ISO, install OS, install VMware Tools, apply baseline updates, and run Sysprep." -ForegroundColor Yellow

# 9. Disconnect from vCenter
Disconnect-VIServer -Server $VIServer -Confirm:$false
