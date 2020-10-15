  ########### Runbook by MK to start or Stop Appication Gateway instance
  ### note - stopped Application Gateways do not incur charges
  Param
  (
    [Parameter (Mandatory= $true)]
    [String] $ApplicationGateway,
  
    [Parameter (Mandatory= $true)]
    [String] $ApplicationGatewayResourceGroup,

    [Parameter (Mandatory= $false)]
    [String] $Subscriptionname,
  
    [Parameter (Mandatory= $true)]
    [boolean] $start
  )
    
  $connectionName = "AzureRunAsConnection"
  try
  {
      # Get the connection "AzureRunAsConnection "
      $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
  
      "Logging in to Azure..."
      Add-AzAccount `
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
      } 
      else {
          Write-Error -Message $_.Exception
          throw $_.Exception
      }
  }
  
  if ($Subscriptionname)
  {
    set-azcontext -subscription $Subscriptionname
  }
  
  # Start or Stopp an Application Gateway

  $appgwobject = Get-AzApplicationgateway -Name $ApplicationGateway -ResourceGroupName $ApplicationGatewayResourceGroup

  if ($start -eq "true") {
      Start-AzApplicationGateway -ApplicationGateway $appgwobject
      
      while ($appgwobject.OperationalState -eq "Starting") 
      {
        Write-Output "Application Gateway $appgwobject.name is still starting"
        $appgwobject = Get-AzApplicationGateway -ResourceGroupName $ApplicationGatewayResourceGroup -Name $ApplicationGateway
      }
      Write-Output "The Application Gateway $appgwobject.name is now $appgwobject.Operationalstate"
  }

  else {
    Stop-AzApplicationGateway -ApplicationGateway $appgwobject
    while ($appgwobject.ProvisioningState -eq "Updating") 
      {
        Write-Output "Application Gateway $appgwobject.name is still stopping"
        $appgwobject = Get-AzApplicationGateway -ResourceGroupName $ApplicationGatewayResourceGroup -Name $ApplicationGateway
      }
    Write-Output "The Application Gateway $appgwobject.name is now $appgwobject.Operationalstate"
  }

  