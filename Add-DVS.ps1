Connect-VIServer -Server vcsa.vaa.local

# ESXi hosts to migrate from VSS-&gt;VDS
$vmhost_array = @("esx1.vaa.local", "esx2.vaa.local", "esx3.vaa.local")

# Create VDS
$vds_name = "VDS-01"
Write-Host "`nCreating new VDS" $vds_name
$vds = New-VDSwitch -Name $vds_name -Location (Get-Datacenter -Name "HomeLab")

# Create DVPortgroup
Write-Host "Creating new Management DVPortgroup"
New-VDPortgroup -Name "Management Network" -Vds $vds | Out-Null
Write-Host "Creating new Storage DVPortgroup"
New-VDPortgroup -Name "Storage Network" -Vds $vds | Out-Null
Write-Host "Creating new vMotion DVPortgroup"
New-VDPortgroup -Name "vMotion Network" -Vds $vds | Out-Null
Write-Host "Creating new VM DVPortgroup`n"
New-VDPortgroup -Name "VM Network" -Vds $vds | Out-Null

foreach ($vmhost in $vmhost_array) {
# Add ESXi host to VDS
Write-Host "Adding" $vmhost "to" $vds_name
$vds | Add-VDSwitchVMHost -VMHost $vmhost | Out-Null

# Migrate pNIC to VDS (vmnic0/vmnic1)
Write-Host "Adding vmnic0/vmnic1 to" $vds_name
$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic0
$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false
$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic1
$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false

# Migrate VMkernel interfaces to VDS

# Management #
$mgmt_portgroup = "Management Network"
Write-Host "Migrating" $mgmt_portgroup "to" $vds_name
$dvportgroup = Get-VDPortgroup -name $mgmt_portgroup -VDSwitch $vds
$vmk = Get-VMHostNetworkAdapter -Name vmk0 -VMHost $vmhost
Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -confirm:$false | Out-Null

# Storage #
$storage_portgroup = "Storage Network"
Write-Host "Migrating" $storage_portgroup "to" $vds_name
$dvportgroup = Get-VDPortgroup -name $storage_portgroup -VDSwitch $vds
$vmk = Get-VMHostNetworkAdapter -Name vmk1 -VMHost $vmhost
Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -confirm:$false | Out-Null

# vMotion #
$vmotion_portgroup = "vMotion Network"
Write-Host "Migrating" $vmotion_portgroup "to" $vds_name
$dvportgroup = Get-VDPortgroup -name $vmotion_portgroup -VDSwitch $vds
$vmk = Get-VMHostNetworkAdapter -Name vmk2 -VMHost $vmhost
Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -confirm:$false | Out-Null

# Migrate remainder pNIC to VDS (vmnic2/vmnic3)
Write-Host "Adding vmnic2/vmnic3 to" $vds_name
$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic2
$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false
$vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic3
$vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false

# Remove old vSwitch portgroups
$vswitch = Get-VirtualSwitch -VMHost $vmhost -Name vSwitch0

Write-Host "Removing vSwitch portgroup" $mgmt_portgroup
$mgmt_pg = Get-VirtualPortGroup -Name $mgmt_portgroup -VirtualSwitch $vswitch
Remove-VirtualPortGroup -VirtualPortGroup $mgmt_pg -confirm:$false

Write-Host "Removing vSwitch portgroup" $storage_portgroup
$vmotion_pg = Get-VirtualPortGroup -Name $vmotion_portgroup -VirtualSwitch $vswitch
Remove-VirtualPortGroup -VirtualPortGroup $vmotion_pg -confirm:$false

Write-Host "Removing vSwitch portgroup" $vmotion_portgroup
$storage_pg = Get-VirtualPortGroup -Name $storage_portgroup -VirtualSwitch $vswitch
Remove-VirtualPortGroup -VirtualPortGroup $storage_pg -confirm:$false
Write-Host "`n"
}

<i><b>Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false
