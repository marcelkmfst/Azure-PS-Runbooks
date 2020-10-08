  ########### Runbook by MK to start or Stop Appication Gateway instance
  ### note - stopped Application Gateways do not incur charges
  Param
  (
    [Parameter (Mandatory= $true)]
    [String] $ApplicationGateway,
  
    [Parameter (Mandatory= $true)]
    [String] $ApplicationGatewayResourceGroup,
  
    [Parameter (Mandatory= $true)]
    [boolean] $start,
     
    
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
      } else{
          Write-Error -Message $_.Exception
          throw $_.Exception
      }
  }
  
  
  # Start a firewall

  $appgwobject = Get-AzApplicationgateway -Name $ApplicationGateway -ResourceGroupName $ApplicationGatewayResourceGrou

  if ($start -eq "true") {
      Start-AzApplicationGateway -ApplicationGateway $appgwobject
      
  }

  else {
    Stop-AzApplicationGateway -ApplicationGateway $appgwobject
  }

  