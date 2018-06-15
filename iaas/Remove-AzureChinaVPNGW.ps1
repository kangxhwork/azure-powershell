# Part 1: On Mooncake, delete VPN GW, Local Gateway, VPN Connection

    $MCconnectionName = "MCRunAsConnection"   
    $MCservicePrincipalConnection=Get-AutomationConnection -Name $MCconnectionName         
    $MCEnv = Get-AzureRmEnvironment -Name AzureChinaCloud

    Add-AzureRmAccount -Environment $MCEnv -ServicePrincipal -TenantId $MCservicePrincipalConnection.TenantId -ApplicationId $MCservicePrincipalConnection.ApplicationId -CertificateThumbprint $MCservicePrincipalConnection.CertificateThumbprint 
    Set-AzureRmContext -SubscriptionId c4013028-2728-46b8-acf1-e397840c4344
    
    $Connection = Get-AzureRmVirtualNetworkGatewayConnection -Name mc-connection-az-gw -ResourceGroupName mooncake.allenk.lab -ErrorAction Ignore
    if ($Connection -ne $null)
    {
        "remove Mooncake connection"
        Remove-AzureRmVirtualNetworkGatewayConnection -Name mc-connection-az-gw -ResourceGroupName mooncake.allenk.lab -Force
    }

    $localGW = get-AzureRmLocalNetworkGateway -Name mc-local-gw-az -ResourceGroupName "mooncake.allenk.lab" -ErrorAction Ignore
    if ($localGW -ne $null)
    {
        "remove Mooncake local gateway"
        Remove-AzureRmLocalNetworkGateway -Name mc-local-gw-az -ResourceGroupName mooncake.allenk.lab -Force
    }

    $GW = Get-AzureRmVirtualNetworkGateway -Name mc-vpn-gw -ResourceGroupName mooncake.allenk.lab -ErrorAction Ignore
    if ($GW -ne $null)
    {
        "remove Mooncake gateway"
        Remove-AzureRmVirtualNetworkGateway -Name mc-vpn-gw -ResourceGroupName mooncake.allenk.lab -Force
    }

    $GWPIP = Get-AzureRmPublicIpAddress -Name mc-pip-vpn -ResourceGroupName mooncake.allenk.lab -ErrorAction Ignore
    if ($GWPIP -ne $null)
    {
        "Remove Mooncake PIP"
        Remove-AzureRmPublicIpAddress -Name mc-pip-vpn -ResourceGroupName mooncake.allenk.lab -Force 
    }

# Part 2: on Global Azure, Delete UDR

    $AzConnectionName = "AzureRunAsConnection"
    $AzServicePrincipalConnection=Get-AutomationConnection -Name $AzConnectionName         
    Add-AzureRmAccount -ServicePrincipal -TenantId $AzServicePrincipalConnection.TenantId -ApplicationId $AzServicePrincipalConnection.ApplicationId -CertificateThumbprint $AzServicePrincipalConnection.CertificateThumbprint 
    Set-AzureRmContext -SubscriptionId 9c6835cb-2079-4f99-96f4-74029267e0df

    $Connection = Get-AzureRmVirtualNetworkGatewayConnection -Name az-connection-mc-gw -ResourceGroupName azure.allenk.lab -ErrorAction Ignore
    if ($Connection -ne $null)
    {
        "remove Azure connection"
        Remove-AzureRmVirtualNetworkGatewayConnection -Name az-connection-mc-gw -ResourceGroupName azure.allenk.lab -Force
    }

    $localGW = get-AzureRmLocalNetworkGateway -Name az-local-gw-mc -ResourceGroupName "azure.allenk.lab" -ErrorAction Ignore
    if ($localGW -ne $null)
    {
        "remove Azure local gateway"
        Remove-AzureRmLocalNetworkGateway -Name az-local-gw-mc -ResourceGroupName azure.allenk.lab -Force
    }

    $GW = Get-AzureRmVirtualNetworkGateway -Name az-vpn-gw -ResourceGroupName azure.allenk.lab -ErrorAction Ignore
    if ($GW -ne $null)
    {
        "remove Azure gateway"
        Remove-AzureRmVirtualNetworkGateway -Name az-vpn-gw -ResourceGroupName azure.allenk.lab -Force
    }

    $GWPIP = Get-AzureRmPublicIpAddress -Name az-pip-vpn -ResourceGroupName azure.allenk.lab -ErrorAction Ignore
    if ($GWPIP -ne $null)
    {
        "remove Azure PIP"
        Remove-AzureRmPublicIpAddress -Name az-pip-vpn -ResourceGroupName azure.allenk.lab -Force 
    }
