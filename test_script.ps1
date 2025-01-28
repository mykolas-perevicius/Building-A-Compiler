Param(
    [string]$PythonExe = "python"  # or "python3", depending on how Python is installed
)

# Change to the directory of this script, just in case
Set-Location $PSScriptRoot

# Path to rosetta.py (assumes rosetta.py is in the same folder as test_script.ps1)
$rosettaPath = ".\rosetta.py"

# Path to the provided folder that has *.list and *.answer files
$providedDir = ".\provided"

# Check that rosetta.py exists
if (-not (Test-Path $rosettaPath)) {
    Write-Host "ERROR: Could not find rosetta.py at path '$rosettaPath'."
    Write-Host "Make sure rosetta.py and this test_script.ps1 are in the same folder."
    exit 1
}

# Check that provided folder exists
if (-not (Test-Path $providedDir)) {
    Write-Host "ERROR: The folder '$providedDir' does not exist."
    exit 1
}

# Collect all .list files
$listFiles = Get-ChildItem -Path $providedDir -Filter *.list -File
if ($listFiles.Count -eq 0) {
    Write-Host "No *.list test files found in '$providedDir'."
    exit 0
}

Write-Host "`nRunning tests..."

# Keep track of results
$passCount = 0
$failCount = 0
$results = @()

foreach ($listFile in $listFiles) {
    $baseName = $listFile.BaseName      # e.g. "cycle" from "cycle.list"
    $answerFile = Join-Path $providedDir ($baseName + ".answer")

    Write-Host "`n========================================"
    Write-Host "Test File:    $($listFile.Name)"
    Write-Host "Answer File:  $($answerFile | Split-Path -Leaf)"

    # If no matching answer file, skip (or treat as fail)
    if (-not (Test-Path $answerFile)) {
        Write-Host "WARNING: No matching .answer file found for '$($listFile.Name)'. Skipping."
        continue
    }

    # Run rosetta.py with the .list file piped as stdin
    $output = (Get-Content $listFile.FullName | & $PythonExe $rosettaPath)

    # Read expected lines
    $expected = Get-Content $answerFile

    # Convert both to single multiline strings to compare easily
    $outputString = ($output -join "`n").Trim()
    $expectedString = ($expected -join "`n").Trim()

    if ($outputString -eq $expectedString) {
        Write-Host "Result: PASS"
        $passCount++
        $results += "[PASS] $($listFile.Name)"
    }
    else {
        Write-Host "Result: FAIL"
        $failCount++
        $results += "[FAIL] $($listFile.Name)"

        Write-Host "`n--- EXPECTED ---"
        Write-Host $expectedString
        Write-Host "--- GOT ---"
        Write-Host $outputString
        Write-Host "--------------"
    }
}

Write-Host "`n========================================"
Write-Host "TEST SUMMARY:"
foreach ($r in $results) {
    Write-Host $r
}
Write-Host "========================================"
Write-Host "PASSED: $passCount"
Write-Host "FAILED: $failCount"
Write-Host "========================================"
