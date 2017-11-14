

# Connect to AAD
username = '<username>';
$credentials = Get-Credential -UserName $username -Message 'Enter password for AAD';
$connection = Connect-AzureAD -Credential $credentials;

# Get a list of all purchased licenses
$subscribedSkus = Get-AzureADSubscribedSku;

# Create an E3 license object that meets our scenario
# We'll determine the disabled plans by excluding all enabled plans from available plans in E3 license
$e3LicenseSkuNumber = "ENTERPRISEPACK";
$e3EnabledPlans = @("MCOSTANDARD", "SHAREPOINTENTERPRISE", "SHAREPOINTWAC");
$e3LicenseSku = $subscribedSkus | Where {$_.SkuPartNumber -eq $e3LicenseSkuNumber};
$e3DisabledPlans = $e3LicenseSku.ServicePlans | ForEach-Object {$_ | Where {$_.ServicePlanName -notin $e3EnabledPlans}};
$e3License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense;
$e3License.SkuId = $e3LicenseSku.SkuId;
$e3License.DisabledPlans = $e3DisabledPlans.ServicePlanId;

# Collection to hold our licenses.
# We can add more licenses here e.g. if you need to assign an EMS license too.
$licensesToAdd = @();
$licensesToAdd += $e3License;

# Import users from CSV.
# CSV file should have a UserPrincipalName property.
$users = Import-Csv "<csv file path>";
$usageLocation = "NZ";

# Create a list of all disabled plan names. We'll log this to our log file.
$csvOutputDisabledPlanNames = $subscribedSkus.ServicePlans | ForEach-Object {$_ | Where {$_.ServicePlanId -in $licensesToAdd.DisabledPlans}} | Select ServicePlanName;

# Process each user
foreach ($user in $users) {

	# Retrieve AAD User and set its Usage Location.
	# Usage location must be set before license can be assigned.
	$upn = $user.UserPrincipalName;
	$aadUser = Get-AzureADUser -ObjectId $upn;
	Set-AzureADUser -ObjectId $aadUser.UserPrincipalName -UsageLocation $usageLocation;
	
	# Remove Power BI license if user has it currently assigned
	$licensesToRemove = @();
	$pBilicenseSku = $subscribedSkus | Where {$_.SkuPartNumber -eq "POWER_BI_STANDARD"};
	$aadUserLicenses = $aadUser.AssignedLicenses | ForEach-Object {$_ | Where {$_.SkuId -eq $pBilicenseSku.SkuId}};
	if ($aadUserLicenses.length -eq 1) {
		$licensesToRemove += $aadUserLicenses[0].SkuId;
	}

	# Create licenses object and set the licenses to Add and Remove
	$assignedLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses;
	if ($licensesToAdd.length -gt 0) {
		$assignedLicenses.AddLicenses = $licensesToAdd;
	}
	if ($licensesToRemove.length -gt 0) {
		$assignedLicenses.RemoveLicenses = $licensesToRemove;
	}
	
	# Assign licenses to user
	Set-AzureADUserLicense -ObjectId $upn -AssignedLicenses $assignedLicenses;
		
	# Gather output for our log file	
	$csvOutput += [PSCustomObject]@{
		"Upn"                  = $aadUser.UserPrincipalName
		"UsageLocation"        = $aadUser.UsageLocation
		"LicensePlanDisabled"  = $csvOutputDisabledPlanNames
	}
}

# Output the log
$csvOutput | Fl;


