##Used to Standardize your users in Active Directory

$textInfo = (Get-Culture).TextInfo

$userOUs = @(<#Enter OU of Users#>)
$domain = <#yourDomain.com#>

$users = $userOUs | foreach {Get-ADUser -filter * -SearchBase $_}
write-host ("Total users in Selection: {0}" -f $allUsers.count)

foreach ($user in $users) {
    $givenName = $textinfo.ToTitleCase($user.givenName)
    $surname = $textinfo.ToTitleCase($user.surname)
    $name = "{0} {1}" -f $givenName, $surname
    $mail = $textinfo.tolowercase($user.mail)

    if($user.givenName -notmatch $givenName){
        $user | Set-ADUser -GivenName $givenName -WhatIf -Verbose
    }

    if($user.surname -notmatch $surname){
        $user | Set-ADUser -surname $surname -WhatIf -Verbose
    }

    if($user.name -notmatch $name){
        $user | Set-ADUser -Add @{name = $name} 
        $user | Set-ADUser -Add @{displayname = $name} 
    }
    
    if($user.mail -eq $null){
        Set-ADUser -Add @{mail = "{0}.{1}@{2}" -f $givenName,$surname,$domain} #adjust this field to match your domain mail format current first.last@domain.com
        }elseif($user.mail -notmatch $mail){
          $user | Set-ADUser -Add @{name = $name}
        }
    }
}
