Import-Module ActiveDirectory
$csvFilePath = "C:\Users\Administrator\Desktop\Usernames_PROJ1000.csv" #this specifies the path of the csv
$csv = Import-csv $csvFilePath
$Domain = "TEAM3.ULTRASPORT" # the domain that we're unboxing in
$MasterOUname = "Ultrasport" # the ou that everything is going into
$DefaultOUpath = "DC=$(($Domain -split "\.")[0]), DC=$(($Domain -split "\.")[1])"

try {
    New-ADOrganizationalUnit -Name $MasterOUname
}
catch {
    Write-Host "Master OU $MasterOUname already exists" -ForegroundColor Green
}

$DefaultOUpath = "OU=$MasterOUname,$DefaultOUPath"


#this function works
Write-Host "Default path: $defaultPath"
function CreateOU ([string]$name, [string]$path) {

	$ouDN = "$name,$path" 
	
	try { #Check if the OU exists
        Get-ADOrganizationalUnit -Identity $ouDN | Out-Null
        Write-Verbose "OU '$ouDN' already exists."
    }
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { # if the OU doesnt exist
        Write-Host "Creating OU '$ouDN'"
		Write-Host "OUDN :'$ouDN'"
		$pathParts = $path -split ","
		$parentName = $pathParts[0]
		$parentPath = $($pathParts[1..($pathParts.Length - 1)] -join ",")
		if ( (($parentName -split "=")[0]) -eq "DC" ) { #if the Parent OU of the OU youre trying to make is the Domain 
			Write-Host $($path.GetType().Name)
			$name = ($name -split "=")[1]
			New-ADOrganizationalUnit -Name $name -path $path #Make this OU. This is the base case asda
		} else {
			CreateOU -name $parentName -path $parentPath #Repeat all steps for the parent
			$name = ($name -split "=")[1]
			New-ADOrganizationalUnit -Name $name -Path $path #Create the OU
		} # Once the dependant OUs are created
		
    }
	

}


#creates all the OUs this works

#this is going to contain the groups rename base on domain env
New-ADOrganizationalUnit -Name "Groups" -path $defaultPath

foreach($line in $csv){ #For every line in the CSV

	#Creating neccesary OUs if they dont already exist
	try {
		$name = "OU=$line.Department"
		Write-Host "Creating OU $($line.Department)"
		$path = $defaultPath
		CreateOU -name $name -path $path
	}
	catch {
		Write-Host "OU already exists"
	}
	

	#Convert the password into an encrypted string so it can be used as a parameter when creating users
	$password = (ConvertTo-SecureString -AsPlainText "P@ssw0rd" -Force)
	
    Write-Host "Adding user:"
	
	Write-Host "$($line.SamAccountName)"
    Write-Host "$($line.GivenName)"
    Write-Host "$($line.Surname)"
    Write-Host "$($line.Name)"
    Write-Host "$($line.DisplayName)"
    Write-Host "$($line.Department)"
    Write-Host "$($line.path)"
    Write-Host "$($line.UserPrincipalName)"

	$user = @{
		SamAccountName = "$($line.SamAccountName)"
		GivenName = "$($line.GivenName)"
		Surname = "$($line.Surname)"
		Name = "$($line.Name)"
		DisplayName = "$($line.Displayname)"
		AccountPassword = $password
		Department = "$($line.Department)"
		Path = "$($line.path)"
		UserPrincipalName = "$($line.UserPrincipalName)"
	}
    New-ADUser @user
	
	try { #Check if the group exists and if it does try to add the user
        Get-ADGroup -Identity $user.Department
        Write-Verbose "Group $($user.Department) already exists."
		try {#Handle exceptions in the case where the group exists but the user cannot be found (should be impossible)
			Add-ADGroupMember -Identity $user.Department -Members $user.SamAccountName
			Write-Verbose "User $($user.SamAccountName) was added to global group $($user.Department)"
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
			<#Do this if a terminating exception happens#>
			Write-Verbose "Failed to add user to group because user could not be found"
		}

    }
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { # if the OU doesnt exist create it and try to add the user
		Write-Host "Creating Group $($user.Department)"
		New-ADGroup -Name $user.Department -groupscope Global -path "OU=Groups,$defaultPath"  #Make the group.
		#add the user to the group
		Write-Host "Group $($user.Department) was created"
		try {#handles exception in the case where the group did not exist but has been created and the user cannot be found (should be impossible)
			Add-ADGroupMember -Identity $user.Department -Members $user.SamAccountName
			Write-Verbose "User $($user.SamAccountName) was added to global group $($user.Department)"
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
			Write-Verbose "Failed to add user to group because user could not be found"
		}
	}

    
}