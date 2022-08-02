##CSV Headers Required: name,mail,telephoneNumber

$csv = Import-Csv -Path "Replace with CSV Path"
$adUsers = get-aduser -filter * -SearchBase "Replace with OU or Remove Parameter for whole Domain" -Properties name,mail,telephoneNumber

#Uses the mail property of the user to identify user then assign appropriate telephoneNumber
$usersCSV = $csv | foreach { $adUsers |
where -property mail -match $_.mail | 
Set-ADUser -Add @(telephoneNumber="$_.telephoneNumber")}

#Notes
<#

#>
