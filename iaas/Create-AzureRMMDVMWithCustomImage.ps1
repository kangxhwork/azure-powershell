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

    # shared resources
    $vnetCfg  = @{name = "ftavnetce2core";  resourcegroup = "fta-rg-ce2-core";  location = $location; ip = "192.168.0.0/16"; subnet = "k8s"; subnetprefix = "192.168.5.0/24"}
    $imageCfg = @{name = "ftaimagece2rhel"; resourcegroup = "fta-rg-ce2-core";  location = $location; customed=$true}
    $kvCfg =    @{name = "ftakvce2core";    resourcegroup = "fta-rg-ce2-core";  location = $location; secret = "pwd-vm-k8s"}

    # Get Image
    $image = Get-AzureRmImage -ResourceGroupName $imageCfg.resourcegroup -ImageName $imageCfg.name
    
    # Create Credential 
    $adminUsername = Read-Host -Prompt Username
    $Password = Get-AzureKeyVaultSecret -VaultName $kvCfg.name -Name $kvcfg.secret
    $cred = New-Object PSCredential $adminUsername, $Password.SecretValue

    $tags = @{"BillTo" = "fta"; "ManagedBy" = "allenk@microsoft.com"; "Environment" = "Demo"}

# Parameters

    # new resources
    $rgCfg =    @{name = "fta-rg-ce2-k8s";    location = $location}

    $saCfg =    @{name = "ftasace2k8sndiag";   resourcegroup = "fta-rg-ce2-k8s"; location = $location; sku="Standard_LRS"}
    $avsetCfg = @{name = "ftaavsetce2k8sn";    resourcegroup = "fta-rg-ce2-k8s"; location = $location}
    $nlbCfg =   @{name = "ftanlbce2k8sn";      resourcegroup = "fta-rg-ce2-k8s"; location = $location}
    $pipCfg   = @{name = "ftapipce2k8sn";      resourcegroup = "fta-rg-ce2-k8s"; location = $location; dns = "ftapipce2k8sn"; allocation= "dynamic"}

    $vmCfg = @(
        @{name="ftavmce2k8sn1"; resourcegroup = "fta-rg-ce2-k8s"; location = $location; nicName = "nic01-ftavmce2k8sn1"; image = $osImage; size = "Standard_A2_v2"; ip = "192.168.5.21"; natrule = "SSH-ftavmce2k8sn1"; frontendport = 62122; backendport = 22; cred = $vmCred}; 
        @{name="ftavmce2k8sn2"; resourcegroup = "fta-rg-ce2-k8s"; location = $location; nicName = "nic01-ftavmce2k8sn2"; image = $osImage; size = "Standard_A2_v2"; ip = "192.168.5.22"; natrule = "SSH-ftavmce2k8sn2"; frontendport = 62222; backendport = 22; cred = $vmCred};
        @{name="ftavmce2k8sn3"; resourcegroup = "fta-rg-ce2-k8s"; location = $location; nicName = "nic01-ftavmce2k8sn3"; image = $osImage; size = "Standard_A2_v2"; ip = "192.168.5.23"; natrule = "SSH-ftavmce2k8sn3"; frontendport = 62322; backendport = 22; cred = $vmCred};
    )

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
        $subnet = Get-AzureRmVirtualNetworkSubnet -Name $vnetCfg.subnet -VirtualNetwork $vnet
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

        $inboundNATRules=@()
        for ($i=0; $i -lt $vmCfg.Count; $i++){
           $natrule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $vmCfg[$i].natrule -FrontendIpConfiguration $feIpConfig -Protocol TCP -FrontendPort $vmCfg[$i].frontendport -BackendPort $vmCfg[$i].backendport
           $inboundNATRules += $natrule
        }

        $beAddressPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "backendPool-$($avsetCfg.name)"
    
        if ($image.StorageProfile.OsDisk.OsType -eq "Linux"){
            $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "healthProbe-$($avsetCfg.name)" -Protocol tcp -Port 22 -IntervalInSeconds 15 -ProbeCount 2
        }
        else{
            $healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "healthProbe-$($avsetCfg.name)" -Protocol tcp -Port 3389 -IntervalInSeconds 15 -ProbeCount 2
        }

        $nlb = New-AzureRmLoadBalancer -ResourceGroupName $nlbCfg.resourcegroup -Location $nlbCfg.location -Name $nlbCfg.name `
            -FrontendIpConfiguration $feIpConfig -InboundNatRule $inboundNATRules -BackendAddressPool $beAddressPool -Probe $healthProbe
    }

# create nic
    $nics=@()
    for ($i=0; $i -lt $vmCfg.Count; $i++){

        $nic = Get-AzureRmNetworkInterface -ResourceGroupName $vmCfg[$i].resourcegroup -Name $vmCfg[$i].nicname -ErrorAction Ignore
        if ($nic) {
            $nics += $nic 
        }
        else{
            $nic = New-AzureRmNetworkInterface -ResourceGroupName $vmCfg[$i].resourcegroup -Name $vmCfg[$i].nicname -Location $vmCfg[$i].location -Subnet $subnet `
                -LoadBalancerInboundNatRule $nlb.InboundNatRules[$i] -LoadBalancerBackendAddressPool $nlb.BackendAddressPools[0] -PrivateIpAddress $vmCfg[$i].ip 
            $nics += $nic 
        }
    }


# create vm using windows image
for ($i=0; $i -lt $vmCfg.Count; $i++){

    $vm  = New-AzureRMVMConfig -VMName $vmCfg[$i].name -VMSize $vmCfg[$i].size -AvailabilitySetID $avset.Id
    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Credential $cred -ComputerName $vmCfg[$i].name -Linux
    $vm  = Add-AzureRMVMNetworkInterface -VM $vm -Id $nics[$i].Id
    $vm = Set-AzureRmVMSourceImage -VM $vm -Id $Image.id
    $vm = Set-AzureRmVMBootDiagnostics -VM $vm -Enable -ResourceGroupName $vmCfg[$i].resourcegroup -StorageAccountName $sa.StorageAccountName

    New-AzureRMVM -ResourceGroupName $vmCfg[$i].resourcegroup -Location $vmCfg[$i].location -VM $vm -AsJob -ErrorAction Ignore
}

Get-Job | Wait-Job

