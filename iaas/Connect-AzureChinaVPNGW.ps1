# VPN GW is the only connection way between China Azure and Global due to sepereate Subscription and AAD
#  Network Peering and vNet-vNet connection not work in such scenario.
# the script create VPN GW on both side and create connection.

Import-Module C:\kangxh\PowerShell\allenk-Module-Azure.psm1
$mcEnv=@{rg="mc-rg-fta-iaas"; localtion = "chinanorth";    vnet="mc-vnet-fta"; gateway="mc-vpn-fta"; pip="mc-pip-fta-vpngw"}
$azEnv=@{rg="az-rg-fta-iaas"; localtion = "southeastasia"; vnet="az-vnet-fta"; gateway="az-vpn-fta"; pip="mc-pip-fta-vpngw"}

#login to mooncake 
Add-AzureRMAccount-Allenk -myAzureEnv mooncake
$MCSubID = "c4013028-2728-46b8-acf1-e397840c4344"
$MCRGName = "mooncake.allenk.lab"
$MCLocation = "China North"
$MCGWName = "mc-vpn-gw"
$MCvNetName = "mooncake.allenk.lab"
$MCGWPIPName = "mc-pip-vpn"
$MCGWSubnetPrefix = "10.1.254.0/24"
$GWSubnetName = "GatewaySubnet"

$mcRG = Get-AzureRmResourceGroup -Name $mcEnv -Location
$MCvNet = Get-AzureRmVirtualNetwork -Name $MCvNetName -ResourceGroupName $MCRGName

# Create PIP if it does not exist:
$MCPip = Get-AzureRmPublicIpAddress -Name $MCGWPIPName -ResourceGroupName $MCRGName -ErrorAction Ignore
if ($MCPip -eq $null)
{
    $MCPip  = New-AzureRmPublicIpAddress -Name $MCGWPIPName -ResourceGroupName $MCRGName -Location $MCLocation -AllocationMethod Dynamic
}

# Create Gateway subnet if it has not been created.
$MCGWSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $MCvNet -Name $GWSubnetName -ErrorAction Ignore
if ($MCGWSubnet -eq $null)
{
    Add-AzureRmVirtualNetworkSubnetConfig -Name $GWSubnetName -AddressPrefix $MCGWSubnetPrefix -VirtualNetwork $MCvNet | Set-AzureRmVirtualNetwork
}

# Create Gateway using the vNet and PIP created before
$MCGW = Get-AzureRmVirtualNetworkGateway -Name $MCGWName -ResourceGroupName $MCRGName -ErrorAction Ignore
if ($MCGW -eq $null)
{
    $MCGWSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $MCvNet
    $MCGWIpConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name "MCGWIpConfig" -Subnet $MCGWSubnet -PublicIpAddress $MCPip
    $MCGW = New-AzureRmVirtualNetworkGateway -Name $MCGWName -ResourceGroupName $MCRGName -Location $MCLocation -IpConfigurations $MCGWIpConfig -GatewayType Vpn -VpnType RouteBased -GatewaySku Basic -AsJob
}

azure
======
$connectionName = "AzureRunAsConnection"
    
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    $RGName = "azure.allenk.lab"
    $Location = "southeastasia"
    $GWName = "az-vpn-gw"
    $vNetName = "azure.allenk.lab"
    $GWPIPName = "az-pip-vpn"
    $GWSubnetPrefix = "10.0.254.0/24"
    $GWSubnetName = "GatewaySubnet"

    set-AzureRmContext -SubscriptionId 9c6835cb-2079-4f99-96f4-74029267e0df

    $RG = Get-AzureRmResourceGroup -Name $RGName -Location $Location
    $vNet = Get-AzureRmVirtualNetwork -Name $vNetName -ResourceGroupName $RGName

    # Create PIP if it does not exist:
    $Pip = Get-AzureRmPublicIpAddress -Name $GWPIPName -ResourceGroupName $RGName -ErrorAction Ignore
    if ($Pip -eq $null)
    {
        $Pip  = New-AzureRmPublicIpAddress -Name $GWPIPName -ResourceGroupName $RGName -Location $Location -AllocationMethod Dynamic
    }

    # Create Gateway subnet if it has not been created.
    $GWSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vNet -Name $GWSubnetName -ErrorAction Ignore
    if ($GWSubnet -eq $null)
    {
        Add-AzureRmVirtualNetworkSubnetConfig -Name $GWSubnetName -AddressPrefix $GWSubnetPrefix -VirtualNetwork $vNet | Set-AzureRmVirtualNetwork
    }
 
    # Create Gateway using the vNet and PIP created before
    $GW = Get-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName -ErrorAction Ignore
    if ($GW -eq $null)
    {
        $GWSubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vNet
        $GWIpConfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name "GWIpConfig" -Subnet $GWSubnet -PublicIpAddress $Pip
        $GW = New-AzureRmVirtualNetworkGateway -Name $GWName -ResourceGroupName $RGName -Location $Location -IpConfigurations $GWIpConfig -GatewayType Vpn -VpnType RouteBased -GatewaySku Basic -AsJob
    }


config
    =====

    # Setup connection environment

    $MCconnectionName = "MCRunAsConnection"   
    $MCservicePrincipalConnection=Get-AutomationConnection -Name $MCconnectionName         
    $MCEnv = Get-AzureRmEnvironment -Name AzureChinaCloud

    $AzconnectionName = "AzureRunAsConnection"
    $AzservicePrincipalConnection=Get-AutomationConnection -Name $AzconnectionName  


# vNet-vNet cannot work. only IPset can work. 
# Step 1: On Mooncake, get Network Gateway

    "switch to Mooncake"
    Add-AzureRmAccount -Environment $MCEnv -ServicePrincipal -TenantId $MCservicePrincipalConnection.TenantId -ApplicationId $MCservicePrincipalConnection.ApplicationId -CertificateThumbprint $MCservicePrincipalConnection.CertificateThumbprint 
    Set-AzureRmContext -SubscriptionId c4013028-2728-46b8-acf1-e397840c4344
    
    # mooncake gateway
    $MCGWPIP = Get-AzureRmPublicIpAddress -ResourceGroupName mooncake.allenk.lab -Name mc-pip-vpn
    $MCGW = Get-AzureRmVirtualNetworkGateway -ResourceGroupName mooncake.allenk.lab -Name mc-vpn-gw -ErrorAction Ignore
    if ($MCGW -eq $null) {exit}

# Step 2: On Global azure, get Network Gateway

    "switch to global azure"
    Add-AzureRmAccount -ServicePrincipal -TenantId $AzservicePrincipalConnection.TenantId -ApplicationId $AzservicePrincipalConnection.ApplicationId -CertificateThumbprint $AzservicePrincipalConnection.CertificateThumbprint 
    Set-AzureRmContext -SubscriptionId 9c6835cb-2079-4f99-96f4-74029267e0df

    $AzGWPIP = Get-AzureRmPublicIpAddress -ResourceGroupName azure.allenk.lab -Name az-pip-vpn
    $AzGW = Get-AzureRmVirtualNetworkGateway -ResourceGroupName azure.allenk.lab -Name az-vpn-gw -ErrorAction Ignore
    if ($AzGW -eq $null) {exit}

# Step 3: On Mooncake, create MCGW-AzGW connection

    "switch to Mooncake"
    Add-AzureRmAccount -Environment $MCEnv -ServicePrincipal -TenantId $MCservicePrincipalConnection.TenantId -ApplicationId $MCservicePrincipalConnection.ApplicationId -CertificateThumbprint $MCservicePrincipalConnection.CertificateThumbprint 
    Set-AzureRmContext -SubscriptionId c4013028-2728-46b8-acf1-e397840c4344

    $MCLocalGW = New-AzureRmLocalNetworkGateway -Name mc-local-gw-az -ResourceGroupName mooncake.allenk.lab -Location 'China North' -GatewayIpAddress $AzGWPIP.IpAddress  -AddressPrefix '10.0.0.0/16'
    New-AzureRmVirtualNetworkGatewayConnection -Name mc-connection-az-gw -ResourceGroupName mooncake.allenk.lab -Location 'China North' -VirtualNetworkGateway1 $MCGW -LocalNetworkGateway2 $MCLocalGW -ConnectionType IPsec -RoutingWeight 10 -SharedKey 'AzureA1b2C3'

# Step 4: On Global Azure, create AzGW-MCGW connection

    "switch to global azure"
    Add-AzureRmAccount -ServicePrincipal -TenantId $AzservicePrincipalConnection.TenantId -ApplicationId $AzservicePrincipalConnection.ApplicationId -CertificateThumbprint $AzservicePrincipalConnection.CertificateThumbprint 
    Set-AzureRmContext -SubscriptionId 9c6835cb-2079-4f99-96f4-74029267e0df

    $AzLocalGW = New-AzureRmLocalNetworkGateway -Name az-local-gw-mc -ResourceGroupName azure.allenk.lab -Location 'southeastasia' -GatewayIpAddress $MCGWPIP.IpAddress  -AddressPrefix '10.1.0.0/16'
    New-AzureRmVirtualNetworkGatewayConnection -Name az-connection-mc-gw -ResourceGroupName azure.allenk.lab -Location 'southeastasia' -VirtualNetworkGateway1 $AzGW -LocalNetworkGateway2 $AzLocalGW -ConnectionType IPsec -RoutingWeight 10 -SharedKey 'AzureA1b2C3'

    