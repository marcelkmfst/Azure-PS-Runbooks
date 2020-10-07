##Runbook which remediates all NON-compliant resources for a given resource group
 
param
(
    [parameter(Mandatory = $false)]
    [string] $resourceGroupName,
    
    [parameter(Mandatory = $false)]
    [string] $azureRunAsConnectionName = "AzureRunAsConnection",
    
    [parameter(Mandatory = $false)]
    [string] $SubscriptionID,
    
     
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
# be careful, collects all policies to which the logged on account has permissions
# current example performs remediation for all Management groups
#$currentpolicystate = Get-Azpolicystatesummary  ## gives only all non-compliant policies and Get-azpolicystate gives all
try
{
    # outcomment, because the subscription is actually not attached to a ManagementGroup from Malon or Vinzenz.
    #$nonCompliancePolicyDefinitions = (Get-AzPolicyStateSummary -SubscriptionId $SubscriptionID).PolicyAssignments | where {$_.PolicyAssignmentId -like "/providers/microsoft.management/managementgroups/$managementGroupID/*"}
    Write-Output "Loading the PolicySummary from subscription"
    $policyAssignment = (Get-AzPolicyStateSummary -SubscriptionId $SubscriptionID).PolicyAssignments | Where-Object {$PSItem.PolicyAssignmentId -like ("/subscriptions/{0}/providers/microsoft.authorization/policyassignments/*" -f $SubscriptionID)}
    Write-Output "OK"
    Write-Output ("Found '{0}' policyAssignment" -f $policyAssignment.Count)
 
    #above outputs list with all non-compliant policies
    [string] $subscriptionname = (Get-AzSubscription -SubscriptionId $SubscriptionID).name
    Select-AzSubscription -Subscription $subscriptionname | out-null
    
    foreach($policy in $policyAssignment)
    {
        [string] $policyAssignmentId = $policy.PolicyAssignmentId
        Write-Output ("Processing PolicyAssignmentID: '{0}' for Subscription: {1}" -f $policyAssignmentId, $subscriptionname)
        foreach($PolicyDefinitionReferenceId in $policy.PolicyDefinitions)
        {
            Write-Output ("Performing PolicyDefinition Remediation: '{0}' for Subscription: {1}" -f $policy.PolicyAssignmentId, $subscriptionname)
    
            Write-Output ("Start Policy Remediation for policyDefinitionReferenceId: {0}" -f $PolicyDefinitionReferenceId)
            $RemediationTask = Start-AzPolicyRemediation -Name (New-Guid) `
                                -PolicyAssignmentId $policy.PolicyAssignmentId `
                                -ResourceDiscoveryMode ReEvaluateCompliance `
                                -PolicyDefinitionReferenceId $PolicyDefinitionReferenceId
 
            while ($Remediationtask.ProvisioningState -eq "Accepted") 
            {
                Write-Output "Remedationtask $RemediationTaskmame in queue - waiting for execution"
                start-sleep -seconds 3
                $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
            }
 
            Write-Output ("Remediationtask left status Accepted")
        
            while ($Remediationtask.ProvisioningState -eq "Evaluating") 
            {
                Write-Output "Policy Remediation in progress...."    
                Start-Sleep -Seconds 3
                $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
            }
            Write-Output ("Remediationtask left status Evaluating")
 
            Write-Output ("Checking the ProvisioningState")
            if ($Remediationtask.ProvisioningState -eq "Failed")
            {
                Write-Output ("Remediaton Task '{0}' for PolicyAssignment failed" -f $remediationtaskname)
            }
            elseif ($Remediationtask.ProvisioningState -eq "Succeeded") 
            {
                Write-Output ("Remediaton Task '{0}' for PolicyAssignment was successful" -f $remediationtaskname)
            }
            else 
            {
                Write-Output ("Unknown state of Remediaton Task '{0}' for PolicyAssignment" -f $remediationtaskname)
            }
        }
    }
}
catch
{
    [string] $errorMessage = ("{0}`r`n{1}" -f $_[0].Exception, $_.InvocationInfo.PositionMessage)
    Write-output ("an error occured: {0}" -f $errorMessage ) -ForegroundColor Red
    throw $_.Exception
}
 
