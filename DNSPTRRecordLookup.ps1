#List of DNS Servers to Scan
$dnsServers = @(
<#Enter list of servers you wish to search here#>
"",
""
)

#Scan each Server in the list to Identify a specific DNS PTR Record
foreach ($server in $dnsservers){
    $reverseLookupZones = (Get-DnsServerZone -ComputerName $server | where {$_.isreverselookupzone -eq "true"}).ZoneName
    
    $records = $reverseLookupZones | foreach {Get-DnsServerResourceRecord -computername "$server" -RRType Ptr -ZoneName "$_" |
    where -Property name -EQ "<#Enter the Record Name Here#>" -ErrorAction SilentlyContinue
    }
    if ($records -ne $null){
        $records | out-file -FilePath "~\desktop\DNSReverseLookupResults.txt" -Append
    }else{
       ("No Records Found on {0}" -f $server) | out-file -FilePath "~\desktop\DNSReverseLookupResults.txt" -Append
    }
} 
