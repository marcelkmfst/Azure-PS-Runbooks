##Runbook which remediates all NON-compliant resources

param
(
    [parameter(Mandatory = $false)]
    [string] $resourceGroupName,
    
    [parameter(Mandatory = $false)]
    [string] $azureRunAsConnectionName = "AzureRunAsConnection",
    
    [parameter(Mandatory = $false)]
    [string] $SubscriptionID = "9076d78f-8a52-4f8d-8567-11b42296bf31",
    
     
    [parameter(Mandatory = $false)]
    [string] $RemediationName = (New-Guid),

    [parameter(Mandatory = $true)]
    [string] $managementGroupID = "MK101CS"
)
 
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"
 
# [string] $connectionName = "AzureRunAsConnection"
# try
# {
#     # Get the connection "AzureRunAsConnection"
#     $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
 
#     Write-Host "Logging in to Azure..."
#     Connect-AzAccount `
#         -ServicePrincipal `
#         -TenantId $servicePrincipalConnection.TenantId `
#         -ApplicationId $servicePrincipalConnection.ApplicationId `
#         -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
# }
# catch 
# {
#     if (!$servicePrincipalConnection)
#     {
#         $ErrorMessage = ("Connection {0} not found." -f $connectionName)
#         throw $ErrorMessage
#     }
#     else
#     { 
#         Write-Error -Message $_.Exception
#         throw $_.Exception
#     }
# }
 
#Perform Policy remedation for the subscriptions

# be careful, collects all policies to which the logged on account has permissions
# current example performs remediation for all Management groups
$currentpolicystate = Get-Azpolicystatesummary  ## gives only all non-compliant policies and Get-azpolicystate gives all
$nonCompliancePolicyDefinitions = (Get-AzPolicyStateSummary -ManagementGroupName $managementGroupid).PolicyAssignments | where {$_.PolicyAssignmentId -like "/providers/microsoft.management/managementgroups/$managementGroupID/*"}

#above outputs list with all non-compliant policies

try
{
    [string] $subscriptionname = (Get-AzSubscription -SubscriptionId $SubscriptionID).name
 

    Select-AzSubscription -Subscription $subscriptionname
  
    
    foreach($policy in $nonCompliancePolicyDefinitions)
    {
        Write-Host  "Performing Policy Remediation for Subscription $subscriptionname"
 
        #Write-Host ("Checking existing remeditation: {0} and policyID: {1}" -f $RemediationName, $PolicyassignmentID)
        #$policyRemediation = Get-AzPolicyRemediation -Filter ("PolicyAssignmentId eq '{0}'" -f $PolicyassignmentID) -ErrorAction SilentlyContinue | Where-Object {$psItem.ProvisioningState -eq "Evaluating"}
        #if($null -ne $policyRemediation)
        #{
        #    Write-Host ("PolicyRemediation already in progress: {0}" -f ($policyRemediation | Out-String) )
        #    return ""
        #}
    
        Write-Output ("Start Policy Remediation for policyDefinitionReferenceId: {0}" -f $policy.policyDefinitionReferenceId)
        $RemediationTask = Start-AzPolicyRemediation -Name (New-Guid) -Scope "/subscriptions/9076d78f-8a52-4f8d-8567-11b42296bf31/resourceGroups/RG-Policyeval" -PolicyAssignmentId $PolicyassignmentID -ResourceDiscoveryMode ReEvaluateCompliance -PolicyDefinitionReferenceId $policy.policyDefinitionReferenceId
        $RemediationTask
        # $RemediationTaskName = Get-AzPolicyRemediation -Name $RemediationTaskName.Name
        # $Remediationtaskname = $RemediationTask.Name
        $PolicyAssignmentObject = Get-AzPolicyAssignment -Id $PolicyassignmentID
        $PolicyAssignmentname = $PolicyAssignmentObject.Name

        while ($Remediationtask.ProvisioningState -eq "Accepted") 
        {
            Write-Output "Remedationtask $RemediationTaskmame in queue - waiting for execution"
            start-sleep -seconds 3
            $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
        }
    
    
        while ($Remediationtask.ProvisioningState -eq "Evaluating") 
        {
            Write-Host "Policy Remediation in progress...."    
            Start-Sleep -Seconds 3
            $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
        }
    
    
        if ($Remediationtask.ProvisioningState -eq "Failed")
        {
            Write-Host -ForegroundColor Red "Remediaton Task $remediationtaskname for PolicyAssignment $PolicyAssignmentname failed"
        }
        elseif ($Remediationtask.ProvisioningState -eq "Succeeded") 
        {
            Write-Host -ForegroundColor green "Remediaton Task $remediationtaskname for PolicyAssignment $PolicyAssignmentname was successful"
        }
        else 
        {
            Write-Host -ForegroundColor yellow "Unknown state of Remediaton Task $remediationtaskname for PolicyAssignment $PolicyAssignmentname"
        }
    }
}
catch
{
    [string] $errorMessage = ("{0}`r`n{1}" -f $_[0].Exception, $_.InvocationInfo.PositionMessage)
    Write-Host ("an error occured: {0}" -f $errorMessage ) -ForegroundColor Red
    throw $_.Exception
}
 

