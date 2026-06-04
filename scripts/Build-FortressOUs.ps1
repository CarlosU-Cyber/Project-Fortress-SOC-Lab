Import-Module ActiveDirectory

# Project Fortress - Baseline OU Structure
# Purpose: Create the initial AD OU structure for infrastructure, admin, service, user, and security group organization.

$ErrorActionPreference = "Stop"

# Detect the current AD domain distinguished name automatically
$domainDN = (Get-ADDomain).DistinguishedName

# Define root OU
$rootOUName = "Fortress-Corp"
$rootOUPath = "OU=$rootOUName,$domainDN"

function New-OUIfMissing {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $existingOU = Get-ADOrganizationalUnit `
        -Filter "Name -eq '$Name'" `
        -SearchBase $Path `
        -SearchScope OneLevel `
        -ErrorAction SilentlyContinue

    if ($null -eq $existingOU) {
        Write-Host "Creating OU: $Name" -ForegroundColor Green

        New-ADOrganizationalUnit `
            -Name $Name `
            -Path $Path `
            -ProtectedFromAccidentalDeletion $true
    }
    else {
        Write-Host "OU already exists: $Name" -ForegroundColor Yellow
    }
}

Write-Host "Building Project Fortress OU structure..." -ForegroundColor Cyan

# Create root OU if missing
New-OUIfMissing -Name $rootOUName -Path $domainDN

# Define baseline sub-OUs
$ouNames = @(
    "Tier 0 - Management",
    "Tier 1 - Production",
    "DMZ Systems",
    "Admin Accounts",
    "Service Accounts",
    "Standard Users",
    "Security Groups"
)

foreach ($ou in $ouNames) {
    New-OUIfMissing -Name $ou -Path $rootOUPath
}

Write-Host "Enterprise OU structure completed successfully." -ForegroundColor Cyan
