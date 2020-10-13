<#
    .SYNOPSIS
        Remediate Azure Services and Diagnostics Settings policies.
        This is the new version from dimitri which performs remediation at 
        the management group level
    
    .DESCRIPTION
  
    .NOTES
        This PowerShell script was developed to auto remediate diagnostic settings options on Azure Ressources.
    
    .COMPONENT
    
    .LINK
#>

# Parameter set
param (
    [parameter(Mandatory = $true)]
    [String] $managementGroupName # Management Group where the Policy Initiative is created
)

# Connect to Azure
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName       
    "Logging in to Azure..."
    Connect-AzureRmAccount `
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

# Running script
$nonCompliancePolicyDefinitions = (Get-AzPolicyStateSummary -ManagementGroupName $managementGroupName).PolicyAssignments | where {$_.PolicyAssignmentId -like "/providers/microsoft.management/managementgroups/$managementGroupName/*"}

foreach ($nonCompliancePolicyDefinition in $nonCompliancePolicyDefinitions) {
    $nonCompliantPolicies = @();
    $PolicyDefinitions = $nonCompliancePolicyDefinition.PolicyDefinitions
    foreach ($item in $PolicyDefinitions) {
        if ($item.Effect -eq 'deployifnotexists'-and $item.Results.NonCompliantResources -ne 0) {
            $nonCompliantPolicies += $item
        }
    }

    #run remediation task
    if ($nonCompliantPolicies) {
        write-output "Start Initiative remediation $($nonCompliancePolicyDefinition.PolicySetDefinitionId)"   
        #write-output $nonCompliantPolicies
        foreach ($policy in $nonCompliantPolicies) {
            $DateTime = ("{0:yyyy-MM-dd-HH-mm-ss}" -f (get-date)).ToString()
            $name = "autoremediation-" + $DateTime
            $polName = (Get-AzureRmPolicyDefinition -Id $policy.PolicyDefinitionId).Properties.displayName
            try {
                $job = Start-AzureRmPolicyRemediation -ManagementGroupName $managementGroupName -PolicyAssignmentId $nonCompliancePolicyDefinition.PolicyAssignmentId -Name $name -PolicyDefinitionReferenceId $policy.PolicyDefinitionReferenceId -ErrorAction Stop -ErrorVariable errmsg | Out-Null
                Write-Output "+ Start Policy remediation: $polName"
            }
            catch {
                if ($errmsg -notlike "*BadRequest*") {
                    Write-Error "$_"
                }
                else {

                    Write-Output "- ERROR Request: $_ - PolicyName: $polName"
                }
            }
        }
    }
}
