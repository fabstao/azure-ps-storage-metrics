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

function Get-AzStgMetrics {
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
	(Get-AzMetric -ResourceId $ResId -StartTime $StTime -TimeGrain $TGrain -MetricName $MetricN -DetailedOutput).Data | Export-Csv -Path "data\raw-$ResName-$Rrid"
	Import-Csv -Path "data\raw-$ResName-$Rrid" | Select-Object *,@{Name='Metric';Expression={$MetricN}} | Select-Object *,@{Name='Namespace';Expression={$Environment}} | 
	Export-Csv -Path "data\$ResourceName-$Rrid"
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
$days = -5
$roles = @('Mobilligy.Internal', 'Mobilligy.JobWorker', 'Mobilligy.WebSite', 'Mobilligy.Partner', 'Mobilligy.PartnerJobWorker', 'Mobilligy.COS')
$roles= @('WebRole1','WorkerRole1')
# ---------------------

# $ResourceId = (Get-AzResource | Where-Object {($_.ResourceType -like "*Microsoft.ClassicCompute/domainNames*") -and ($_.Name -like "*latam*")}).ResourceID # Additional name based filter
$ResourceId = (Get-AzResource | Where-Object {($_.ResourceType -like "*ClassicCompute*domainNames*") -and ($_.Name -like "*")}).ResourceID
 
#$metrics = Get-AzMetricDefinition -ResourceId $ResourceId[0]

$fecha = (Get-Date).AddDays($days)
Write-Output "StartTime: $fecha"

#$metrics| Select-Object @{Name="Name";Expression={$_.Name.Value}},@{Name="Tag";Expression={$_.Name.LocalizedValue}},@{Name="PrimaryAggregationEnvironment";Expression={$_.PrimaryAggregationEnvironment}},@{Name="Unit";Expression={$_.Unit}} | Format-Table
Foreach ($i in $ResourceId) 
{
	Write-Output "Resource: $i"
	$ResourceName = (Get-AzResource -ResourceId $i).Name
	
	Foreach ($j in $roles) {

		# Get Staging CPU
		Get-AzStgMetrics -ResId $i/slots/staging/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "PercentageCPU" -Environment "staging" -Rrid $cpu_web

		# Get Network Ingress
		Get-AzStgMetrics -ResId $i/slots/staging/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "NetworkIn" -Environment "staging" -Rrid $trans_table
		
		# Get Network Egress/Out
		Get-AzStgMetrics -ResId $i/slots/staging/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "NetworkOut" -Environment "staging" -Rrid $trans_table

		# Get Production CPU
		Get-AzStgMetrics -ResId $i/slots/production/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "PercentageCPU" -Environment "production" -Rrid $cpu_web

		# Get Network Ingress
		Get-AzStgMetrics -ResId $i/slots/production/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "NetworkIn" -Environment "production" -Rrid $trans_table
		
		# Get Network Egress/Out
		Get-AzStgMetrics -ResId $i/slots/production/roles/$j -ResName $ResourceName -StTime $fecha -TGrain 01:00:00 -MetricN "NetworkOut" -Environment "production" -Rrid $trans_table

	}

	# Merge metrics
	Get-ChildItem -Path "data" -Filter "$ResourceName*.csv" | Select-Object -ExpandProperty FullName | Import-Csv | Export-Csv data\Merged-$ResourceName.csv -NoEnvironmentInformation -Append
	Remove-Item "data\$ResourceName-*.csv"
	Remove-Item "data\raw-*.csv"
}
