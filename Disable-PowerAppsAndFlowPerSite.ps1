
# * Disable PowerApps and Flow for Site Collections using STS#0 or BLANKINTERNET#0 templates.
# * Use commitUpdates = $false to run the script without making any updates.

# Get all your sites
Connect-SPOService -Url <admin site url>;
$sites = Get-SPOSite -Limit All;
$commitUpdates = $false;
$log = @();

foreach ($site in $sites) {
  Write-Host "Processing --> $($site.Template), $($site.Url)" -ForegroundColor Green;
  
  # Determine if we need to act on the site
  $disable = ($site.Template -in @("STS#0", "BLANKINTERNET#0") -and ($site.DisableFlows -ne "Disabled" -or $site.DisableAppViews -ne "Disabled"));
  
  if($disable -eq $true){
	Write-Host "       Disabling Flow/PowerApps --> $($site.url)" -ForegroundColor Red;
	if($commitUpdates -eq $true){
		$site | Set-SPOSite -DisableAppViews Disabled -DisableFlows Disabled;
	}
  }	

  $log += [PSCustomObject]@{
	"Site"		= $site.Title
	"Url"		= $site.Url
	"CurrentStatusFlow" = $site.DisableFlows
	"CurrentStatusPowerApps" = $site.DisableAppViews
	"Template"	= $site.Template
	"UpdatedToDisable" = $disable
  };
}

$csvOutFilePath = "<file system location>" + (Get-Date -Format FileDateTime) + ".csv";
$log | Export-Csv $csvOutFilePath;
Invoke-Item $csvOutFilePath;
