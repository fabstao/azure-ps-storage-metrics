# ***************************************************************************
# * (C) Rackspace 2021      -       fabian.salamanca@rackspace.com          *
# * Usage: ./getdata.ps1                                                    *
# * Azure PowerShell Module must be installed:                              *
# * Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force *
# ***************************************************************************

# Check if user is logged in
$account = Get-AzContext
if(($null -eq $account) -or ($account -eq "")) {
	Connect-AzAccount 
}

function Get-AzClSvMetrics {
	[CmdletBinding()]
	param (
		$ResId,
		$ResName,
		$StTime,
		$TGrain,
		$MetricN,
		$Environment,
		$Rrid
	)
	$flag=0
	try {
		(Get-AzMetric -ResourceId $ResId -StartTime $StTime -TimeGrain $TGrain -MetricName $MetricN -DetailedOutput).Data | Export-Csv -Path "data\raw-$ResName-$Rrid"
		$flag=1
	}
	catch {
		Write-Output "Not found or error in metrics, skipping $ResName"
	}
	if($flag -gt 0) {
		Import-Csv -Path "data\raw-$ResName-$Rrid" | Select-Object *,@{Name='Metric';Expression={$MetricN}} | Select-Object *,@{Name='Namespace';Expression={$Environment}} | 
		Export-Csv -Path "data\$ResourceName-$Rrid"
	}
}

# Configuration section
# ---------------------
$WarningPreference = 'SilentlyContinue'
$cpu_web = "_cloudsvc_cpu_web.csv"
$cpu_worker = "_cloudsvc_cpu_worker.csv"
$ingress_web = "_cloudsvc_ingress_web.csv"
$ingress_worker = "_cloudsvc_ingress_worker.csv"
$egress_web = "_cloudsvc_egress_web.csv"
$egress_worker = "_cloudsvc_egress_worker.csv"
$days = -1
$roles = @('Mobilligy.Internal', 'Mobilligy.JobWorker', 'Mobilligy.WebSite', 'Mobilligy.Partner', 'Mobilligy.PartnerJobWorker', 'Mobilligy.COS')
#$roles= @('WebRole1','WorkerRole1')
#$envs = @('staging','production')
$envs = @('production')
# ---------------------

# $ResourceId = (Get-AzResource | Where-Object {($_.ResourceType -like "*Microsoft.ClassicCompute/domainNames*") -and ($_.Name -like "*latam*")}).ResourceID # Additional name based filter
$ResourceId = (Get-AzResource | Where-Object {($_.ResourceType -like "*ClassicCompute*domainNames*") -and ($_.Name -like "*")}).ResourceID
 
$metrics = Get-AzMetricDefinition -ResourceId $ResourceId[0]/slots/production/roles/WebRole1

$fecha = (Get-Date).AddDays($days)
Write-Output "StartTime: $fecha"

#$metrics| Select-Object @{Name="Name";Expression={$_.Name.Value}},@{Name="Tag";Expression={$_.Name.LocalizedValue}},@{Name="PrimaryAggregationEnvironment";Expression={$_.PrimaryAggregationEnvironment}},@{Name="Unit";Expression={$_.Unit}} | Format-Table
Foreach ($i in $ResourceId) 
{
	$ResourceName = (Get-AzResource -ResourceId $i).Name
	Write-Output "Resource: $ResourceName"
	
	Foreach ($j in $roles) {

		# Get Staging CPU
		#Write-Output "Retrieving: $i/slots/staging/roles/$j"
		#Get-AzClSvMetrics -ResId $i/slots/staging/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "Percentage CPU" -Environment "staging" -Rrid cpustg$j.csv

		# Get Network Ingress
		#Write-Output "Retrieving: $i/slots/staging/roles/$j"
		#Get-AzClSvMetrics -ResId $i/slots/staging/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "Network In" -Environment "staging" -Rrid instg$j.csv
		
		# Get Network Egress/Out
		#Write-Output "Retrieving: $i/slots/staging/roles/$j"
		#Get-AzClSvMetrics -ResId $i/slots/staging/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "Network Out" -Environment "staging" -Rrid outstg$j.csv
		Foreach ($env in $envs) {	
			# Get Production CPU
			Write-Output "Retrieving: $i/slots/$env/roles/$j"
			Get-AzClSvMetrics -ResId $i/slots/$env/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "Percentage CPU" -Environment "$env" -Rrid cpuprod$j.csv

			# Get Network Ingress
			Write-Output "Retrieving: $i/slots/$env/roles/$j"
			Get-AzClSvMetrics -ResId $i/slots/$env/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "Network In" -Environment "$env" -Rrid inprod$j.csv
			
			# Get Network Egress/Out
			Write-Output "Retrieving: $i/slots/$env/roles/$j"
			Get-AzClSvMetrics -ResId $i/slots/$env/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "Network Out" -Environment "$env" -Rrid outprod$j.csv
		}

	}

	# Merge metrics
	Get-ChildItem -Path "data" -Filter "$ResourceName*.csv" | Select-Object -ExpandProperty FullName | Import-Csv | Export-Csv data\Merged-$ResourceName.csv -NoTypeInformation -Append
	Remove-Item "data\$ResourceName-*.csv"
	Remove-Item "data\raw-*.csv"
}
