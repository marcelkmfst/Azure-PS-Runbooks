##Runbook which remediates all NON-compliant resources at Managementgroup level
#

param
(
    
    [parameter(Mandatory = $false)]
    [string] $azureRunAsConnectionName = "AzureRunAsConnection",
    
             
    [parameter(Mandatory = $false)]
    [string] $RemediationName = (New-Guid),

    [parameter(Mandatory = $true)]
    [string] $managementGroupID
)
 
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"
 
[string] $connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection"
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
 
    Write-Output "Logging in to Azure..."
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
$currentpolicystate = Get-Azpolicystatesummary  ## gives only all non-compliant policies and Get-azpolicystate gives all
$nonCompliancePolicyDefinitions = (Get-AzPolicyStateSummary -ManagementGroupName $managementGroupid).PolicyAssignments | where {$_.PolicyAssignmentId -like "/providers/microsoft.management/managementgroups/$managementGroupID/*"}

#above outputs list with all non-compliant policies

try
{
     
    
    foreach($policy in $nonCompliancePolicyDefinitions.PolicyDefinitions)
    {
        Write-Output  "Performing Policy Remediation"
        $RemediationTask = Start-AzPolicyRemediation -Name (New-Guid) -PolicyAssignmentId $nonCompliancePolicyDefinitions.PolicyAssignmentId -ResourceDiscoveryMode ReEvaluateCompliance -PolicyDefinitionReferenceId $Policy.PolicyDefinitionId
        $RemediationTask
        

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
            Write-Output  "Remediaton Task $RemediationTask.Name for PolicyAssignment $Policy.PolicyDefinitionId failed"
        }
        elseif ($Remediationtask.ProvisioningState -eq "Succeeded") 
        {
            Write-Output  "Remediaton Task $RemediationTask.Name for PolicyAssignment $Policy.PolicyDefinitionId was successful"
        }
        else 
        {
            Write-Output  "Unknown state of Remediaton Task $RemediationTask.Name for PolicyAssignment $Policy.PolicyDefinitionId"
        }
    }
}
catch
{
    [string] $errorMessage = ("{0}`r`n{1}" -f $_[0].Exception, $_.InvocationInfo.PositionMessage)
    Write-Output ("an error occured: {0}" -f $errorMessage ) 
    throw $_.Exception
}
 

