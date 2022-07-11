$runTime = get-date -Format "yyyyMMddHHmm"
$servers = [System.Collections.ArrayList]::new()

##Add names from a CS
$getCSV = Import-Csv -Path #Enter Path Here
$getCSV | foreach {
$name = $_ | select -ExpandProperty #Property representing ADObject Name
$servers.Add($name)
}

##Add names individually
<#
do{
$servername = Read-Host "Please enter Host name"
$servers.add(($servername))
}while($servername -notlike $null)
$servers.remove("")
#>

$servers | foreach{
    Get-ADObject -SearchBase <#Enter a Searchbase Here#> -Filter * -Properties lastlogontimestamp, pwdlastset,operatingsystem,operatingsystemversion|
    where -Property name -match $_ | 
        select Name,@{Name='LastLogonTimestamp';Expression={[DateTime]::fromfiletime($_.lastlogontimestamp)}}, @{Name='pwdlastset';Expression={[DateTime]::fromfiletime($_.pwdlastset)}},operatingsystem,operatingsystemversion | 
        fl | Out-File -FilePath ("C:\Users\admin_zk11354\Desktop\AuditADObjects{0}.txt" -f $runTime) -Append
    Write-host ("{0} added to file" -f $_) -ForegroundColor Cyan
}

#@{Name='LastLogonTimestamp';Expression={[DateTime]::fromfiletime($_.lastlogontimestamp)}}
