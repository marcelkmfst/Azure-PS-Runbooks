## Runbook which performs remidiation per PolicyAssignment (re-evaluation is triggered before to capture not-started state)
param
(
    [parameter(Mandatory = $false)]
    [string] $resourceGroupName,
    
    [parameter(Mandatory = $false)]
    [string] $azureRunAsConnectionName = "AzureRunAsConnection",
    
    [parameter(Mandatory = $false)]
    [string] $SubscriptionID = "9076d78f-8a52-4f8d-8567-11b42296bf31",
    
    [parameter(Mandatory = $true)]
    [string] $PolicyassignmentID,

    [parameter(Mandatory = $false)]
    [string] $initiativeID = "/providers/Microsoft.Management/managementGroups/110c879b-9489-4244-9d7e-113d8dcf5875/providers/Microsoft.Authorization/policySetDefinitions/f68c4d4a-10c4-4b7c-9baa-61425f442b21",
 
    [parameter(Mandatory = $false)]
    [string] $RemediationName = (New-Guid)
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
try
{
    [string] $subscriptionname = (Get-AzSubscription -SubscriptionId $SubscriptionID).name
 

    Select-AzSubscription -Subscription $subscriptionname
  
    $initiative = Get-AzPolicySetDefinition -id $initiativeID
    $policies = $initiative.Properties.PolicyDefinitions
    foreach($policy in $policies)
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
            start-sleep -seconds 10
            $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
        }
    
    
        while ($Remediationtask.ProvisioningState -eq "Evaluating") 
        {
            Write-Output "Policy Remediation in progress...."    
            Start-Sleep -Seconds 10
            $RemediationTask = Get-AzPolicyRemediation -ResourceId $RemediationTask.Id
        }
    
    
        if ($Remediationtask.ProvisioningState -eq "Failed")
        {
            Write-Output "Remediaton Task $remediationtaskname for PolicyAssignment $PolicyAssignmentname failed"
        }
        elseif ($Remediationtask.ProvisioningState -eq "Succeeded") 
        {
           Write-Output "Remediaton Task $remediationtaskname for PolicyAssignment $PolicyAssignmentname was successful"
        }
        else 
        {
            Write-Output "Unknown state of Remediaton Task $remediationtaskname for PolicyAssignment $PolicyAssignmentname"
        }
    }
}
catch
{
    [string] $errorMessage = ("{0}`r`n{1}" -f $_[0].Exception, $_.InvocationInfo.PositionMessage)
    Write-Host ("an error occured: {0}" -f $errorMessage ) -ForegroundColor Red
    throw $_.Exception
}
 

