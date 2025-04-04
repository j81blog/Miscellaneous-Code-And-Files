# Define the VM name
$vmName = "VMName"
$lastNrCheckpointsToKeep = 3
$snapshotsToExclude = @("Before_RunBook")

# Get the VM object
$vm = Get-SCVirtualMachine -Name $vmName

# Get all checkpoints (snapshots), sorted by AddedTime (oldest first)
$snapshots = Get-SCVMCheckpoint -VM $vm | Where-Object Name -NotIn $snapshotsToExclude | Sort-Object -Property AddedTime

# Calculate how many snapshots to delete
$nrToDelete = $snapshots.Count - $lastNrCheckpointsToKeep

if ($nrToDelete -gt 0) {
    $snapshots | Select-Object -First $nrToDelete | ForEach-Object {
        Write-Host "Removing snapshot: $($_.Name)"
        $null = Remove-SCVMCheckpoint -VMCheckpoint $_ -Confirm:$false
    }
    Write-Host "Cleanup complete. Only the last 3 snapshots remain."
} else {
    Write-Host "The VM has 3 or fewer snapshots. No action taken."
}