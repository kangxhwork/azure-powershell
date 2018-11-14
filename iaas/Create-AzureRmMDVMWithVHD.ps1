Import-Module C:\kangxh\PowerShell\allenk-Module-Azure.psm1
Add-AzureRMAccount-Allenk -myAzureEnv mooncake
$contextEnv = Get-AzureRmContext

# Naming Conversion
# ProjectName:   fta
# Resource Type: vnet; avset; nlb; pip; image; kv; sa
# region: ce2
# usage: core; k8s
# tag: BillTo = fta; ManagedBy = allenk@microsoft.com; Environment = Demo


# Environment setup
    $location = "chinaeast2"
    $tags = @{"BillTo" = "fta"; "ManagedBy" = "allenk@microsoft.com"; "Environment" = "Demo"}


# Parameters

    # new resources
    $vnetCfg  = @{name = "ftavnetce2core";    resourcegroup = "fta-rg-ce2-core";  location = $location; ip = "192.168.0.0/16"; subnet = "oss"; subnetprefix = "192.168.4.0/24"}
    
    $rgCfg =    @{name = "fta-rg-ce2-oss";    location = $location}

    $saCfg =    @{name = "ftasace2ossdiag";   resourcegroup = "fta-rg-ce2-oss"; location = $location; sku="Standard_LRS"}

    $avsetCfg = @{name = "ftaavsetce2oss";    resourcegroup = "fta-rg-ce2-oss"; location = $location}
    $nlbCfg =   @{name = "ftanlbce2oss";      resourcegroup = "fta-rg-ce2-oss"; location = $location}
    $pipCfg   = @{name = "ftapipce2oss";      resourcegroup = "fta-rg-ce2-oss"; location = $location; dns = "ftapipce2oss"; allocation= "dynamic"}

    $vmCfg = @{name="ftavmce2centos"; resourcegroup = "fta-rg-ce2-oss"; location = $location; nicName = "nic01-ftavmce2centos"; diskname = "ftavmce2centos-os"; ostype = "Linux"; diskuri="https://ftasace2corev1.blob.core.chinacloudapi.cn/vhds/centos73.vhd"; storagesku="Standard_LRS"; size = "Standard_A2_v2"; ip = "192.168.4.12"; natrule = "SSH-ftavmce2centos"; frontendport = 61222; backendport = 22}; 


# Provisioning

# create resource group.
    $rg = Get-AzureRmResourceGroup -Name $rgCfg.name -Location $rgCfg.location -ErrorAction Ignore
    if($null -eq $rg){
        $rg = New-AzureRmResourceGroup -Name $rgCfg.name -Location $rgCfg.location -Tag $tags
    }

    # create storage account: 
    $sa = Get-AzureRmStorageAccount -ResourceGroupName $saCfg.resourcegroup -Name $saCfg.name -ErrorAction Ignore
    if ($null -eq $sa){
        $sa = New-AzureRmStorageAccount -ResourceGroupName $saCfg.resourcegroup -Name $saCfg.name -Location $saCfg.location -Type $saCfg.sku
    }

# create vnet
    $vnet = Get-AzureRmVirtualNetwork -Name $vnetCfg.name -ResourceGroupName $vnetCfg.resourcegroup -ErrorAction Ignore
    if ($null -eq $vnet){
        $vnet = New-AzureRmVirtualNetwork -Name $vnetCfg.name -ResourceGroupName $vnetCfg.resourcegroup -Location $vnetCfg.location -AddressPrefix $vnetCfg.ip -Subnet $subnet
    }

    $subnet = Get-AzureRmVirtualNetworkSubnetConfig  -Name $vnetCfg.subnet -VirtualNetwork $vnet -ErrorAction Ignore
    if ($null -eq $subnet){
        Add-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $vnetCfg.subnet -AddressPrefix $vnetCfg.subnetprefix
        Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
        $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $vnetCfg.subnet -VirtualNetwork $vnet
    }

# create avset
    $avset = Get-AzureRmAvailabilitySet -ResourceGroupName $avsetCfg.resourcegroup  -Name $avsetCfg.name -ErrorAction Ignore
    if ($null -eq $avset){
        $avset = New-AzureRmAvailabilitySet -ResourceGroupName $avsetCfg.resourcegroup  -Name $avsetCfg.name -Location $avsetCfg.location -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 5 -Sku Aligned
    }

# create pip
    $pip = Get-AzureRmPublicIpAddress -ResourceGroupName $pipCfg.resourcegroup -Name $pipCfg.name -ErrorAction Ignore
    if ($null -eq $pip) {
        $pip = New-AzureRmPublicIpAddress -ResourceGroupName $pipCfg.resourcegroup -Name $pipCfg.name -Location $pipCfg.location -AllocationMethod $pipCfg.allocation -DomainNameLabel $pipCfg.dns
    }

# create nlb
    $nlb = Get-AzureRmLoadBalancer -ResourceGroupName $nlbCfg.resourcegroup -Name $nlbCfg.name -ErrorAction Ignore
    if ($null -eq $nlb) {
        $feIpConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name "frontendIP-$($pipCfg.name)" -PublicIpAddress $pip
        $natrule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $vmCfg.natrule -FrontendIpConfiguration $feIpConfig -Protocol TCP -FrontendPort $vmCfg.frontendport -BackendPort $vmCfg.backendport
        $beAddressPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "backendPool-$($avsetCfg.name)"
    
        if ($vmCfg.ostype -eq "Linux"){
            $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "healthProbe-$($avsetCfg.name)" -Protocol tcp -Port 22 -IntervalInSeconds 15 -ProbeCount 2
        }
        else{
            $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "healthProbe-$($avsetCfg.name)" -Protocol tcp -Port 3389 -IntervalInSeconds 15 -ProbeCount 2
        }

        $nlb = New-AzureRmLoadBalancer -ResourceGroupName $nlbCfg.resourcegroup -Location $nlbCfg.location -Name $nlbCfg.name -FrontendIpConfiguration $feIpConfig -InboundNatRule $natrule -BackendAddressPool $beAddressPool -Probe $healthProbe
    }
    else{

        $feIpConfig = Get-AzureRmLoadBalancerFrontendIpConfig -LoadBalancer $nlb
        $inboundNatRuleConfig = Get-AzureRmLoadBalancerInboundNatRuleConfig -LoadBalancer $nlb
        $beAddressPoolConfig = Get-AzureRmLoadBalancerBackendAddressPoolConfig -LoadBalancer $nlb
    
        if (($beAddressPoolConfig.Name -eq "backendPool-$($avset.name)") -and ($feIpConfig.Name -eq "frontendIP-$($pip.name)")){ # this VM has same PIP configure and belongs to same avset, add NAT rule
            Add-AzureRmLoadBalancerInboundNatRuleConfig -LoadBalancer $nlb -Name $vmCfg.natrule -FrontendIpConfiguration $feIpConfig -Protocol TCP -FrontendPort $vmCfg.frontendport -BackendPort $vmCfg.backendport | Set-AzureRmLoadBalancer

            $nlb = Get-AzureRmLoadBalancer -ResourceGroupName $nlbCfg.resourcegroup -Name $nlbCfg.name -ErrorAction Ignore
            $natrule = $nlb.InboundNatRules.GetEnumerator() | where {$_.Name -eq $vmCfg.natrule}
        }
    }

# create nic
   $nic = Get-AzureRmNetworkInterface -ResourceGroupName $vmCfg.resourcegroup -Name $vmCfg.nicname -ErrorAction Ignore
    if ($null -eq $nic) {
        $nic = New-AzureRmNetworkInterface -ResourceGroupName $vmCfg.resourcegroup -Name $vmCfg.nicname -Location $vmCfg.location -Subnet $subnet -LoadBalancerInboundNatRule $natrule -LoadBalancerBackendAddressPool $nlb.BackendAddressPools[0] -PrivateIpAddress $vmCfg.ip 
    }


# create vm using existing vhd
    $diskConfig = New-AzureRmDiskConfig -AccountType $vmCfg.storagesku -Location $vmCfg.location -CreateOption import -SourceUri $vmCfg.diskuri -OsType Linux 
    $osDisk = New-AzureRmDisk -ResourceGroupName $vmCfg.resourcegroup -DiskName $vmCfg.diskname -Disk $diskConfig

    $vm = New-AzureRmVMConfig -VMName $vmCfg.name -VMSize $vmCfg.size -AvailabilitySetId $avset.Id
    Set-AzureRmVMOSDisk -vm $vm -ManagedDiskId $osDisk.Id -Caching ReadOnly -CreateOption attach -Linux -Name $osDisk.Name -StorageAccountType Standard_LRS -DiskSizeInGB 64
    Add-AzureRmVMNetworkInterface -vm $vm -Id $nic.Id

    New-AzureRmVM -ResourceGroupName $vmCfg.resourcegroup -Location $vmCfg.location -VM $vm

