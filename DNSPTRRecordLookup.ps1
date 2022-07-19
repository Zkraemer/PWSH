#List of DNS Servers to Scan
$dnsServers = @(
<#Enter Servers to Scan Here#>
"",
""
)
$targetRecord = ""<#Enter Record IP you'd like to lookup#>

#Scan each Server in the list to Identify a specific DNS PTR Record with matching name
foreach ($server in $dnsservers){
    $reverseLookupZones = (Get-DnsServerZone -ComputerName $server | where {$_.isreverselookupzone -eq "true"}).ZoneName
    
    $records = $reverseLookupZones | foreach  {
        Get-DnsServerResourceRecord -computername "$server" -RRType Ptr -ZoneName "$_" |
        where -Property hostname -Like ($targetRecord.split(".")[-1]) -ErrorAction SilentlyContinue
    }
    
    if ($records -notlike $null){
        $records | out-file -FilePath "~\desktop\DNSReverseLookupResults.txt" -Append
        ("Total Records Found on {0}: {1}" -f $server,$records.count) | out-file -FilePath "~\desktop\DNSReverseLookupResults.txt" -Append
    }else{
        ("No Records Found on {0}" -f $server) | out-file -FilePath ("~\desktop\DNSReverseLookupResults_for_{0}.txt" -f $targetRecord) -Append
    }
} 


#Notes
<#
Use this script to find PTR records in the DNS Reverse Lookup Zones on specific Servers.
This script will pull all files that match the 4 Quartet of the IP address.
Use this to Identify if there are mismatches or errors across your Domains DNS.
#>
