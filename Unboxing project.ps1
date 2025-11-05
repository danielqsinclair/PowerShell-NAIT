Import-Module -Name ActiveDirectory
$csvPath = "C:/Users/Administrator/Desktop/Usernames_PROJ1000.csv" # the loction of the csv
$UnboxCsv = Import-Csv -Path $csvPath
$Domain = "TEAM3.ULTRASPORT" # the domain that we're unboxing in
$MasterOUname = "Ultrasport" # the ou that everything is going into
$DefaultOUpath = "DC=$(($Domain -split "\.")[0]),DC=$(($Domain -split "\.")[1])"
try {
    New-ADOrganizationalUnit -Name $MasterOUname -path $DefaultOUpath
}
catch {
    Write-Host "Master OU $MasterOUname already exists" -ForegroundColor Green
}
$DefaultOUpath = "OU=$MasterOUname,$DefaultOUPath"

foreach($line In $UnboxCsv){
    try {
        New-ADOrganizationalUnit -Name $line.Department -Path $DefaultOUpath -ProtectedFromAccidentalDeletion $false
    }
    catch {
        Write-Host "OU $($line.Department) already exists" -ForegroundColor Green
    }
    try {
        New-ADGroup -Name "GG $($line.Department)" -GroupScope Global -Path "OU=$($line.Department),$DefaultOUpath"
    }
    catch  {
        Write-Host "Group $($line.Department) already exists" -ForegroundColor Green
    }
    #set password
    $password = (ConvertTo-SecureString -AsPlainText "P@ssw0rd" -Force)

    Write-Host "$($line.First)$($line.Last)"
    Write-Host "$($line.First) $($line.Last)"
    Write-Host $line.Department
    Write-Host "OU=$($line.Department),$DefaultOUpath"
    $newUser = @{
        SamAccountName = "$($line.First)$($line.Last)"
        Name = "$($line.First) $($line.Last)" 
        Department = $line.Department
        Path = "OU=$($line.Department),$DefaultOUpath"
        AccountPassword = $password
        Enabled = $true
    }
    try {
        New-AdUser @newUser
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Host "User $($line.First) $($line.Last) already exists" -ForegroundColor Green
    } catch {
        Write-Error "Unexpected error making user"
    }
    Add-ADGroupMember -Identity "GG $($line.Department)" -Members "$($line.First)$($line.Last)"
}

