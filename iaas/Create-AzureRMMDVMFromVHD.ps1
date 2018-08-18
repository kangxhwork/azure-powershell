
Import-Module C:\kangxh\PowerShell\allenk-Module-Azure.psm1
Add-AzureRMAccount-Allenk -myAzureEnv mooncake

$VMName = "mcvmftarhel"

$ResourceGroupName = "mc-rg-fta-vm"
$subnetid = "/subscriptions/e363f44b-9312-44d7-bfc8-6bcef51ee7b8/resourceGroups/mc-rg-fta-core/providers/Microsoft.Network/subnets/web"
$sa = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name mcsaftavm
$Location = "China North"

$AvSet = Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name mc-avset-fta-oss
$NIC = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name "nic01-mcvmftarhel"

$OSDiskUri = "https://mcsaftavm.blob.core.chinacloudapi.cn/vhds/mcvmftarhel-os.vhd"
$DataDiskUri = "https://mcsaftavm.blob.core.chinacloudapi.cn/vhds/mcvmftarhel-data.vhd"
$storageType = "Standard_LRS"

$diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption import -StorageAccountId $sa.Id -SourceUri $OSDiskUri -OsType Linux
New-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName "$VMName-osdisk" -Disk $diskConfig 

$diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption import -StorageAccountId $sa.Id -SourceUri $DataDiskUri
New-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName "$VMName-datadisk" -Disk $diskConfig 

$vm = New-AzureRmVMConfig -VMName $VMName -VMSize Standard_A2_v2 -AvailabilitySetId $AvSet.id
Set-AzureRmVMOSDisk -vm $vm -Name "$VMName-osdisk" -VhdUri $OSDiskUri -Caching ReadOnly -CreateOption attach -Linux 
Add-AzureRmVMDataDisk -VM $vm -Name "$VMName-datadisk" -Lun 0 -CreateOption Attach -VhdUri $DataDiskUri
Add-AzureRmVMNetworkInterface -vm $vm -Id $NIC.Id

New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vm
