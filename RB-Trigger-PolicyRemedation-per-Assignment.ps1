## Runbook which performs remidiation per PolicyAssignment 
## per default, remedation will be performed on subscription level unless you specify A Resource Group or Management GroupID
param
(
    [parameter(Mandatory = $false)]
    [string] $resourceGroupName,
    
    [parameter(Mandatory = $false)]
    [string] $azureRunAsConnectionName = "AzureRunAsConnection",
    
    [parameter(Mandatory = $false)]
    [string] $SubscriptionID,
    
    [parameter(Mandatory = $true)]
    [string] $PolicyassignmentID,

    [parameter(Mandatory = $true)]
    [string] $initiativeID,

    [parameter(Mandatory = $false)]
    [string] $managementGroupID,
 
    [parameter(Mandatory = $false)]
    [string] $Subscription,

    [parameter(Mandatory = $false)]
    [string] $ResourceGroup,

    [parameter(Mandatory = $false)]
    [string] $RemediationName = (New-Guid)
)
 
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"
 
[string] $connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection"
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
 
    Write-Host "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
catch 
{
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = ("Connection {0} not found." -f $connectionName)
        throw $ErrorMessage
    }
    else
    { 
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
 
#Perform Policy remedation for the subscriptions
try
{
    [string] $subscriptionname = (Get-AzSubscription -SubscriptionId $SubscriptionID).name
 

    Select-AzSubscription -Subscription $subscriptionname
  
    $initiative = Get-AzPolicySetDefinition -id $initiativeID
    $policies = $initiative.Properties.PolicyDefinitions
    foreach($policy in $policies)
    {
        Write-Host  "Performing Policy Remediation for Subscription $subscriptionname"
 
        if ($ManagementGroup)
        {
        Write-Output ("Start Policy Remediation for policyDefinitionReferenceId: {0}" -f $policy.policyDefinitionReferenceId)
        $RemediationTask = Start-AzPolicyRemediation -Name (New-Guid) -ManagementGroupName $managementGroupID -PolicyAssignmentId $PolicyassignmentID -ResourceDiscoveryMode ReEvaluateCompliance -PolicyDefinitionReferenceId $policy.policyDefinitionReferenceId
        $RemediationTask
        $PolicyAssignmentObject = Get-AzPolicyAssignment -Id $PolicyassignmentID
        $PolicyAssignmentname = $PolicyAssignmentObject.Name
        }

        elseif ($Resourcegroup) {

            Write-Output ("Start Policy Remediation for policyDefinitionReferenceId: {0}" -f $policy.policyDefinitionReferenceId)
            $RemediationTask = Start-AzPolicyRemediation -Name (New-Guid) -ResourceGroupName $ResourceGroup -PolicyAssignmentId $PolicyassignmentID -ResourceDiscoveryMode ReEvaluateCompliance -PolicyDefinitionReferenceId $policy.policyDefinitionReferenceId
            $RemediationTask
            $PolicyAssignmentObject = Get-AzPolicyAssignment -Id $PolicyassignmentID
            $PolicyAssignmentname = $PolicyAssignmentObject.Name
            
        }

        else {
            Write-Output ("Start Policy Remediation for policyDefinitionReferenceId: {0}" -f $policy.policyDefinitionReferenceId)
            $RemediationTask = Start-AzPolicyRemediation -Name (New-Guid) -PolicyAssignmentId $PolicyassignmentID -ResourceDiscoveryMode ReEvaluateCompliance -PolicyDefinitionReferenceId $policy.policyDefinitionReferenceId
            $RemediationTask
            $PolicyAssignmentObject = Get-AzPolicyAssignment -Id $PolicyassignmentID
            $PolicyAssignmentname = $PolicyAssignmentObject.Name
        }

        while ($Remediationtask.ProvisioningState -eq "Accepted") 
        {
            Write-Output "Remedationtask $RemediationTaskmame in queue - waiting for execution"
            start-sleep -seconds 3
            $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
        }
    
    
        while ($Remediationtask.ProvisioningState -eq "Evaluating") 
        {
            Write-Output "Policy Remediation in progress...."    
            Start-Sleep -Seconds 3
            $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
        }
    
    
        if ($Remediationtask.ProvisioningState -eq "Failed")
        {
            Write-Output "Remediaton Task $remediationtask.name for PolicyAssignment $PolicyAssignmentname failed"
        }
        elseif ($Remediationtask.ProvisioningState -eq "Succeeded") 
        {
           Write-Output "Remediaton Task $remediationtask.name for PolicyAssignment $PolicyAssignmentname was successful"
        }
        else 
        {
            Write-Output "Unknown state of Remediaton Task $remediationtask.name for PolicyAssignment $PolicyAssignmentname"
        }
    }
}
catch
{
    [string] $errorMessage = ("{0}`r`n{1}" -f $_[0].Exception, $_.InvocationInfo.PositionMessage)
    Write-Host ("an error occured: {0}" -f $errorMessage ) -ForegroundColor Red
    throw $_.Exception
}
 

