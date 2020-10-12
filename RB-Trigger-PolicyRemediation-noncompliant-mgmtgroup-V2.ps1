##Runbook which remediates all NON-compliant resources at Management Group Level
 
param
(
     
    [parameter(Mandatory = $false)]
    [string] $azureRunAsConnectionName = "AzureRunAsConnection",
    
    [parameter(Mandatory = $true)]
    [string] $managementgroupid, 
    
    [parameter(Mandatory = $true)]
    [string] $managemengroupname, 
     
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
 


try
{
   
    
    $policyAssignment = (Get-AzPolicyStateSummary -managementgroupname $managementgroupname).PolicyAssignments | Where-Object {$PSItem.PolicyAssignmentId -like ("/providers/microsoft.management/managementgroups/$managementgroupid/*")}
    Write-Output "OK"
    Write-Output ("Found '{0}' policyAssignments" -f $policyAssignment.Count)
 
    # #above outputs list with all non-compliant policies
    # [string] $subscriptionname = (Get-AzSubscription -SubscriptionId $SubscriptionID).name
    # Select-AzSubscription -Subscription $subscriptionname | out-null
    
    foreach($policy in $policyAssignment)
    {
        [string] $policyAssignmentId = $policy.PolicyAssignmentId
        Write-Output ("Processing PolicyAssignmentID: '{0}' for ManagementGroup: $managementgroupname" -f $policyAssignmentId)
        foreach($PolicyDefinitionReferenceId in $policy.PolicyDefinitions)
        {
            Write-Output ("Performing PolicyDefinition Remediation: $policy.PolicyAssignmentId for ManagementGroup: $managementgroupname")
    
            Write-Output ("Start Policy Remediation for policyDefinitionReferenceId: {0}" -f $PolicyDefinitionReferenceId)
            $RemediationTask = Start-AzPolicyRemediation -Name (New-Guid) `
                                -PolicyAssignmentId $policy.PolicyAssignmentId `
                                -ResourceDiscoveryMode ExistingNonCompliant `
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
    Write-output ("an error occured: {0}" -f $errorMessage )
    throw $_.Exception
}
 
 
