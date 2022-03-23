#Credential Build
$VMPrefix = "1BCT-"
$PrimaryDomainController = "DC1"

$domainFQDN = "1BCT3ID.ARMY.MIL"
$domainNETBIOS = $domainFQDN.split('.')[0]
$localUsername = "administrator"
$domainUsername = $domainNETBIOS + "\tsiadministrator"
$conUsername = "admin"
$password = 'Pa55w.rd' | ConvertTo-SecureString -AsPlainText -Force
$conPassword = 'Pa$$w0rd' | ConvertTo-SecureString -AsPlainText -Force

$localCredential = [System.Management.Automation.PSCredential]::new($localUsername,$password)
$domainCredential = [System.Management.Automation.PSCredential]::new($domainUsername,$password)
$consoleCredential = [System.Management.Automation.PSCredential]::new($conUsername,$conPassword)


#Admin Machine Setup
$adminServerNames = @("ADMIN")
$AdminVMName = $AdminServerNames | foreach {$VMPrefix + $_}

$installAdminRoles = {
    $AdminRoles = @(
        "RSAT-ADDS",
        "RSAT-RemoteAccess",
        "RSAT-File-Services",
        "RSAT-DFS-Mgmt-Con",
        "RSAT-FSRM-Mgmt",
        "RSAT-DHCP",
        "RSAT-AD-PowerShell"
        "RSAT-DNS-Server"
    )
    Install-WindowsFeature -Name $AdminRoles
    
}
Invoke-Command -VMName $AdminVMName -ScriptBlock $installAdminRoles -Credential $domainCredential -AsJob


#Create Sites
$ADSiteServicesServers = @("DC1")
$ADSSVMName = $ADSiteServicesServers | foreach {$VMPrefix + $_}

$createSites = {
    $siteLink = Get-ADReplicationSiteLink -Filter *
    $sites = @("MAIN","TAC")

    New-ADReplicationSite -Name MAIN
    New-ADReplicationSite -Name TAC

    New-ADReplicationSubnet -Name "10.3.1.0/24" -Site MAIN
    New-ADReplicationSubnet -Name "10.3.11.0/24" -Site TAC
    
    #Add DC1 to MAIN Site
    #Set-ADReplicationSite -Identity MAIN -Server "DC1"

    $siteLink | Set-ADReplicationSiteLink -ReplicationFrequencyInMinutes 15 -SitesIncluded  @{Add=$sites}
}
Invoke-Command -VMName $ADSSVMName -ScriptBlock $createSites -Credential $domainCredential -AsJob


#Create DisableWindowsFirewall GPO
#force GPUpdate
Get-VM | Select-Object -ExpandProperty Name | foreach {Invoke-Command -VMName $_ -ScriptBlock {start-process gpupdate.exe} -Credential $domainCredential -AsJob}


#DHCP Setup
$DHCPServerNames = @("APPSVR1")
$DHCPVMNames = $VMPrefix + $DHCPServerNames

$installDHCPRoles = {
    $DHCPRoles = @(
        "DHCP"
    )
    Install-WindowsFeature -Name $DHCPRoles 

    $DHCPServerNames | 
    foreach {
        Add-DhcpServerv4Scope -Name MAIN -SubnetMask 255.255.255.0 -StartRange 10.3.1.1 -EndRange 10.3.1.254 -Type Dhcp -State Active 
        Add-DhcpServerv4Scope -Name TAC -SubnetMask 255.255.255.0 -StartRange 10.3.11.1 -EndRange 10.3.11.254 -Type Dhcp -State Active
        Set-DhcpServerv4OptionValue -DnsServer @("10.3.11.1","10.3.1.1") 
                
        Add-DhcpServerv4ExclusionRange -ScopeId 10.3.1.0 -StartRange 10.3.1.1 -EndRange 10.3.1.3 
        Add-DhcpServerv4ExclusionRange -ScopeId 10.3.1.0 -StartRange 10.3.1.254 -EndRange 10.3.1.254

        Add-DhcpServerv4ExclusionRange -ScopeId 10.3.11.0 -StartRange 10.3.11.1 -EndRange 10.3.11.3 
        Add-DhcpServerv4ExclusionRange -ScopeId 10.3.11.0 -StartRange 10.3.11.254 -EndRange 10.3.11.254 
    }
}
Invoke-Command -VMName $DHCPVMNames -Credential $domainCredential -ScriptBlock $installDHCPRoles -AsJob


#Domain Controller Setup
$domainControllerNames = @("DC2")
$ReadOnlyDomainControllerNames = @("RODC")
$AllDCNames = @($domainControllerNames,$ReadOnlyDomainControllerNames)
$AllDCVMNames = $AllDCNames | foreach {$VMPrefix + $_}

$removeRootHints = {
    Get-DnsServerRootHint | Remove-DnsServerRootHint
}
Invoke-Command -VMName 1BCT-DC1 -ScriptBlock $removeRootHints -Credential $domainCredential -AsJob

$installDomainRoles = {
    $domainControllerRoles = @(
        "AD-Domain-Services",
        "DNS"
    )
    $readOnlyDomainControllerRoles = (
        "AD-Domain-Services"
    )

    If ($env:COMPUTERNAME -like "RODC") {
        Install-WindowsFeature -Name $readOnlyDomainControllerRoles  
    }else{
        Install-WindowsFeature -Name $domainControllerRoles
    }
}
Invoke-Command -VMName $domainControllerNames -ScriptBlock $installDomainRoles -Credential $domainCredential -AsJob

$ConfigureDomainControllers = {
$delegatedAdminUsers = @(
    "HQ Users"
)
    $delegatedAdminUsers = Get-ADObject -filter * | where -Property Name -eq $delegatedAdminUsers

    If ($env:COMPUTERNAME -like "RODC") {
        Install-ADDSDomainController -DomainName $using:domainFQDN -Credential $using:domainCredential -NoGlobalCatalog -ReadOnlyReplica -SafeModeAdministratorPassword $using:password -SiteName TAC -SkipPreChecks -DelegatedAdministratorAccountName $delegatedAdminUsers
        Write-Host ($env:COMPUTERNAME + " installed as ReadOnlyReplica on TAC") -ForegroundColor Green 
                
    }Else{
        Install-ADDSDomainController -DomainName $using:domainFQDN -Credential $using:domainCredential -SafeModeAdministratorPassword $using:password -SiteName TAC -SkipPreChecks
        Write-Host ($env:COMPUTERNAME + " Installed as Domain Controller on TAC") -ForegroundColor Green       
        
    }
}
Invoke-Command -VMName $AllDCVMNames -ScriptBlock $ConfigureDomainControllers -Credential $domainCredential -AsJob


#Create AD Objects Within Parent OU
$CreateIMOGroups = {
$Unit = "1BCT3ID"
$Shops = @(
    "HQ",
    "S1",
    "S2",
    "S3",
    "S4",
    "S6"
)

$ParentOU = Get-ADOrganizationalUnit -Filter * | Where -property Name -eq $Unit
$ParentOUName = $ParentOU | select -ExpandProperty name
$ParentOUDistinguishedName = $ParentOU | select -ExpandProperty DistinguishedName

    foreach ($shop in $shops){
        $shopGroupFolder = Get-ADOrganizationalUnit -Filter * -SearchBase "ou=$shop,$ParentOUDistinguishedName" | where -Property Name -like "Groups" 
        $shopGroupDistinguishedName = $shopGroupFolder | select -ExpandProperty distinguishedname
        New-ADGroup -Name "$shop IMOs" -GroupScope Global -GroupCategory Security -Path $shopGroupDistinguishedName
        
    }

New-ADGroup -Name ('{0} IMOs' -f $Unit) -GroupScope Global -GroupCategory Security -Path $ParentOUDistinguishedName

}
Invoke-Command -VMName $PrimaryDomainController -ScriptBlock $CreateIMOGroups -Credential $domainCredential -AsJob


#Add AD IMO Users to Appropriate Group
$AddIMOsToIMOGroup = {
$Unit = "1BCT3ID"
$parentIMOs = @("S6 IMOs")
$Shops = @(
    "HQ",
    "S1",
    "S2",
    "S3",
    "S4",
    "S6"
)
$ParentOU = Get-ADOrganizationalUnit -Filter * | Where -property Name -eq $Unit
$ParentOUName = $ParentOU | select -ExpandProperty name
$ParentOUDistinguishedName = $ParentOU | select -ExpandProperty DistinguishedName

    foreach ($shop in $Shops){
            $shopUsersFolder = Get-ADOrganizationalUnit -Filter * -SearchBase ('OU={0},{1}' -f $Shop, $ParentOUDistinguishedName) | where -Property Name -like "IMOs" 
            $shopUserFolderDistinguishedName = $shopUsersFolder | select -ExpandProperty distinguishedname
            $shopUsers = Get-ADUser -Filter * -SearchBase $shopUserFolderDistinguishedName
            Get-ADGroup -Identity "$shop IMOs" | Add-ADGroupMember -Members $shopUsers -ErrorAction SilentlyContinue          
    }

Get-ADGroup -Identity ('{0} IMOs' -f $Unit) | Add-ADGroupMember -Members $parentIMOs
}
Invoke-Command -VMName ($VMPrefix + $PrimaryDomainController) -ScriptBlock $AddIMOsToIMOGroup -Credential $domainCredential -AsJob

#delegate Control of Parent OU to Group
$delegateOUPermissions = {
$Unit = "1BCT3ID"
$Shops = @(
    "HQ",
    "S1",
    "S2",
    "S3",
    "S4",
    "S6"

)
$ParentOU = Get-ADOrganizationalUnit -Filter * | Where -property Name -eq $Unit
$ParentOUName = $ParentOU | select -ExpandProperty name
$ParentOUDistinguishedName = $ParentOU.DistinguishedName
set-location ad:


foreach ($shop in $Shops){
    
    $shopUsersFolder = Get-ADOrganizationalUnit -Filter * -SearchBase ('OU={0},{1}' -f $Shop, $ParentOUDistinguishedName) | where -Property Name -like $shop 
    $shopUserFolderDistinguishedName = $shopUsersFolder.distinguishedName
        
    $group = Get-ADGroup -Identity ('{0} IMOs' -f $shop)
    $groupSID = [System.Security.Principal.SecurityIdentifier]$group.SID
    $ACL = Get-Acl -Path $shopUserFolderDistinguishedName
    
    $Identity = [System.Security.Principal.IdentityReference]$groupSID
    $ADRight = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
    $Type = [System.Security.AccessControl.AccessControlType]"Allow"
    $InheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance]"ALL"
    $Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Identity,$ADRight,$Type,$InheritanceType)

    $ACL.AddAccessRule($rule)
    Set-Acl -Path $shopUserFolderDistinguishedName -AclObject $ACL 
}
    #Add Parent OU IMO Group
    $group = Get-ADGroup -Identity ('{0} IMOs' -f $Unit)
    $groupSID = [System.Security.Principal.SecurityIdentifier]$group.SID
    $ACL = Get-Acl -Path $ParentOUDistinguishedName
    
    $Identity = [System.Security.Principal.IdentityReference]$groupSID
    $ADRight = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
    $Type = [System.Security.AccessControl.AccessControlType]"Allow"
    $InheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance]"ALL"
    $Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Identity,$ADRight,$Type,$InheritanceType)

    $ACL.AddAccessRule($rule)
    Set-Acl -Path $ParentOUDistinguishedName -AclObject $ACL 

Set-Location c:
}
Invoke-Command -VMName ($VMPrefix + $PrimaryDomainController) -ScriptBlock $delegateOUPermissions -Credential $domainCredential -AsJob

#Assign Cmd Group to RODC
$assignRODCPasswordReplicationPolicy = {
    $authorizedPWReplicaton = @(
        "HQ Users"
    )

    $allowed = Get-ADObject -Filter * | where -Property name -eq $authorizedPWReplicaton
    Add-ADDomainControllerPasswordReplicationPolicy -Identity RODC -allowed $allowed -Confirm:$false
}
Invoke-Command -VMName ('{0}RODC' -f $VMPrefix) -ScriptBlock $assignRODCPasswordReplicationPolicy -Credential $domainCredential -AsJob

#Add Windows Features to APPSVR2
$APPServers = @(
    "APPSVR2",
    "APPSVR1"
)
$AppServerVMNames = $APPServers | foreach {$VMPrefix+$_}

$ConfigureAppServers = {
    $AppSVRRoles = @(
        "FS-DFS-Namespace"
        "FS-DFS-Replication"
        "FS-Resource-Manager"
    )

    If ($env:COMPUTERNAME -like "APPSVR2"){
        Install-WindowsFeature $AppSVRRoles
        Install-WindowsFeature RemoteAccess, DirectAccess-VPN, Routing -Restart
    }else{
        Install-WindowsFeature $AppSVRRoles
    }
}
Invoke-Command -VMName $AppServerVMNames -ScriptBlock $ConfigureAppServers -Credential $domainCredential -AsJob

#Setup DHCP Relay Agent Manually -_- bahhh....

#Create Fileshares on APPSVR1
#get-command *DFS*
$localPath = Get-PSDrive D | select -ExpandProperty root
$NamespaceSOFTWAREPath = ("\\1BCT3ID\SOFTWARE")
$NamespaceMOVIESPath = ("\\1BCT3ID\MOVIES")
New-DfsnRoot -TargetPath $NamespaceSOFTWAREPath -Type DomainV2 -Path ('{0}\SOFTWARE' -f $localPath)
New-DfsnRoot -TargetPath $NamespaceMOVIESPath -Type DomainV2 -Path ('{0}\MOVIES' -f $localPath) -

#FSRM Configuration