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
		$Type,
		$Rrid
	)
	(Get-AzMetric -ResourceId $ResId -StartTime $StTime -TimeGrain $TGrain -MetricName $MetricN -DetailedOutput).Data | Export-Csv -Path "data\raw-$ResName-$Rrid"
	Import-Csv -Path "data\raw-$ResName-$Rrid" | Select-Object *,@{Name='Type';Expression={$MetricN}} | Select-Object *,@{Name='Namespace';Expression={$Type}} | 
	Export-Csv -Path "data\$ResourceName-$Rrid"
}

$WarningPreference = 'SilentlyContinue'
$used_blob = "used_blob_cap.csv"
$used_table = "used_table_cap.csv"
$trans_blob = "transactions_blob.csv"
$trans_table = "transactions_table.csv"
$latencye2e_blob = "latencye2e_blob.csv"
$latencye2e_table = "latencye2e_table.csv"
$ingress_blob = "ingress_blob.csv"
$ingress_table = "ingress_table.csv"
$egress_blob = "egress_blob.csv"
$egress_table = "egress_table.csv"

$ResourceId = (Get-AzResource | Where-Object {($_.ResourceType -like "*storageAccounts*") -and ($_.Name -like "*latam*")}).ResourceID
 
$metrics = Get-AzMetricDefinition -ResourceId $ResourceId[0]

$fecha2 = (Get-Date).AddDays(-2)
$fecha7 = (Get-Date).AddDays(-7)

$metrics| Select-Object @{Name="Name";Expression={$_.Name.Value}},@{Name="Tag";Expression={$_.Name.LocalizedValue}},@{Name="PrimaryAggregationType";Expression={$_.PrimaryAggregationType}},@{Name="Unit";Expression={$_.Unit}} | Format-Table
Foreach ($i in $ResourceId) 
{
	Write-Output "Resource: $i"
	$ResourceName = (Get-AzResource -ResourceId $i).Name
	
	# Get blob capacity
	Get-AzStgMetrics -ResId $i/blobServices/default -ResName $ResourceName -StTime $fecha2 -TGrain 01:00:00 -MetricN "BlobCapacity" -Type "Blob" -Rrid $used_blob
	
	# Get table capacity
	Get-AzStgMetrics -ResId $i/tableServices/default -ResName $ResourceName -StTime $fecha2 -TGrain 01:00:00 -MetricN "TableCapacity" -Type "Table" -Rrid $used_table

	# Get blob transactions
	Get-AzStgMetrics -ResId $i/blobServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "Transactions" -Type "Blob" -Rrid $trans_blob

	# Get table transactions
	Get-AzStgMetrics -ResId $i/tableServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "Transactions" -Type "Table" -Rrid $trans_table
	
	# Get blob latency E2E
	Get-AzStgMetrics -ResId $i/blobServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "SuccessE2ELatency" -Type "Blob" -Rrid $latencye2e_blob
	
	# Get table latency E2E
	Get-AzStgMetrics -ResId $i/tableServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "SuccessE2ELatency" -Type "Table" -Rrid $latencye2e_table

	# Get blob ingress
	Get-AzStgMetrics -ResId $i/blobServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "Ingress" -Type "Blob" -Rrid $ingress_blob

	# Get table ingress
	Get-AzStgMetrics -ResId $i/tableServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "Ingress" -Type "Table" -Rrid $ingress_table

	# Get blob egress
	Get-AzStgMetrics -ResId $i/blobServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "Egress" -Type "Blob" -Rrid $egress_blob

	# Get table egress
	Get-AzStgMetrics -ResId $i/tableServices/default -ResName $ResourceName -StTime $fecha7 -TGrain 01:00:00 -MetricN "Egress" -Type "Table" -Rrid $egress_table

	# Merge metrics
	Get-ChildItem -Filter $ResourceName-*.csv | Select-Object -ExpandProperty FullName | Import-Csv | Export-Csv Merged-$ResourceName.csv -NoTypeInformation -Append
	Remove-Item "$ResourceName-*.csv"
	Remove-Item "raw-*.csv"
}
