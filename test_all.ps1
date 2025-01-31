<#
.SYNOPSIS
  A PowerShell script to compile, test, time, and compare rosetta.* implementations in various languages.

.DESCRIPTION
  - Compiles each language (if needed).
  - Optionally generates some random test cases.
  - Runs each executable/script on all .list files in the test folder.
  - Compares output with .answer files using the 'fc' command.
  - Measures run time with Measure-Command.
  - Logs results to test_results.txt.
#>

Param(
    # If you want to enable or disable random test generation
    [switch]$GenerateExtra = $false,
    # If you want to run the big scaling test
    [switch]$ScaleUp = $false
)

# --- CONFIGURE PATHS ---
# Root folder
$Root = "C:\Users\miciu\Desktop\Compilers (485)"
$ProvidedFolder = Join-Path $Root "provided"
$TestFolder = Join-Path $Root "test"
$ResultsFile = Join-Path $ProvidedFolder "test_results.txt"

# If you have your source files in the root "C:\Users\miciu\Desktop\Compilers (485)\"
# (like rosetta.py, rosetta.c, etc.), define:
$SourceFolder = $Root

# --- LANGUAGES / BUILD COMMANDS / RUN COMMANDS ---
# Each entry is an object with:
#   - Name: a label
#   - Compile: the command to compile (if needed)
#   - ExecCmd: how to run the program (with <input redirection)
#   - OutputFile: how you prefer to name the output
$programs = @(
    @{
        Name = "Python"
        Compile = ""  # no compile step needed
        ExecCmd = "python rosetta.py"
        OutputFile = "python.out"
    },
    @{
        Name = "C"
        Compile = "gcc -O2 -o rosetta_c rosetta.c"
        ExecCmd = ".\rosetta_c.exe"
        OutputFile = "c.out"
    },
    @{
        Name = "C++"
        Compile = "g++ -O2 -std=c++17 -o rosetta_cpp rosetta.cpp"
        ExecCmd = ".\rosetta_cpp.exe"
        OutputFile = "cpp.out"
    },
    @{
        Name = "Java"
        Compile = "javac Rosetta.java"
        ExecCmd = "java Rosetta"
        OutputFile = "java.out"
    },
    @{
        Name = "Kotlin"
        Compile = "kotlinc rosetta.kt -include-runtime -d rosetta.jar"
        ExecCmd = "java -jar rosetta.jar"
        OutputFile = "kotlin.out"
    },
    @{
        Name = "Rust"
        Compile = "rustc -C opt-level=2 rosetta.rs -o rosetta_rs"
        ExecCmd = ".\rosetta_rs.exe"
        OutputFile = "rust.out"
    },
    @{
        Name = "Scala"
        Compile = "scalac Rosetta.scala"
        ExecCmd = "scala Rosetta"
        OutputFile = "scala.out"
    }
    # Add more if you want to test rosetta.php, rosetta.ts, etc.
)

# --- OPTIONAL STEP: GENERATE EXTRA TEST CASES ---
if ($GenerateExtra) {
    Write-Host "Generating extra random test cases..."
    # We'll do a quick inline Python snippet to create a big random test file
    # named big_test.list in the test folder
    $randomTestGen = @"
import random, string

n = 3000  # number of pairs, tweak as desired
tasks = []
for i in range(n):
    # random 5-letter uppercase + i
    t = "".join(random.choices(string.ascii_uppercase, k=5)) + str(i)
    tasks.append(t)

with open("big_test.list","w") as f:
    # let's create n pairs
    for i in range(n):
        task = random.choice(tasks)
        prereq = random.choice(tasks)
        if prereq != task:
            f.write(task + "\n")
            f.write(prereq + "\n")
"@

    $pyScriptFile = Join-Path $TestFolder "generate_big_test.py"
    Set-Content $pyScriptFile $randomTestGen
    # Run it
    python $pyScriptFile
    Remove-Item $pyScriptFile
    Write-Host "big_test.list created."
}

# --- COMPILE EACH LANGUAGE (IF NEEDED) ---
Push-Location $SourceFolder
foreach ($prog in $programs) {
    if ($prog.Compile -ne "") {
        Write-Host "Compiling $($prog.Name)..."
        & $prog.Compile | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Compilation failed for $($prog.Name). Skipping..."
        }
    }
}
Pop-Location

# --- RUN TESTS ---
# We'll gather .list files from the test folder
Write-Host "Running tests..."

# Clear or create the results file
"`n======== Test Results ========`n" | Out-File $ResultsFile

$listFiles = Get-ChildItem $TestFolder -Filter "*.list" | Sort-Object Name

foreach ($listFile in $listFiles) {
    Write-Host "`n*** Testing input: $($listFile.Name) ***"
    "`n*** Testing input: $($listFile.Name) ***`n" | Out-File $ResultsFile -Append

    foreach ($prog in $programs) {
        $exeCmd = $prog.ExecCmd
        if (-not $exeCmd) { continue }

        # We'll measure the time using Measure-Command
        $outPath = Join-Path $TestFolder $prog.OutputFile
        $inPath = $listFile.FullName

        # Some compilers/executables might be in $SourceFolder, so let's do a pushd
        Push-Location $SourceFolder
        $timeTaken = Measure-Command {
            # run command: e.g.  python rosetta.py < file > output
            # In PowerShell, you can do:
            & cmd /c "$exeCmd < `"$inPath`" > `"$outPath`""
        }
        Pop-Location

        # Log time
        $sec = [Math]::Round($timeTaken.TotalSeconds, 3)
        $resultLine = "[$($prog.Name)] completed in $sec seconds"
        Write-Host $resultLine
        $resultLine | Out-File $ResultsFile -Append

        # If there's a corresponding .answer, compare
        $answerFile = $listFile.FullName -replace "\.list$",".answer"
        if (Test-Path $answerFile) {
            # Compare using 'fc' (file compare) to see if there's any difference
            $compareCommand = "fc `"$outPath`" `"$answerFile`""
            $fcResult = cmd /c $compareCommand
            if ($LASTEXITCODE -eq 0) {
                # No differences
                Write-Host "    Output matches .answer"
                "    Output matches .answer" | Out-File $ResultsFile -Append
            }
            else {
                Write-Host "    *** DIFFERENCE from expected ***"
                "    *** DIFFERENCE from expected ***" | Out-File $ResultsFile -Append
            }
        }
        else {
            Write-Host "    No .answer file found for $($listFile.Name)."
            "    No .answer file found" | Out-File $ResultsFile -Append
        }
    }
}

# --- OPTIONAL SCALE-UP TEST ---
if ($ScaleUp) {
    Write-Host "`nNow running scale-up tests on big_test.list if it exists...`n"
    "`nNow running scale-up tests on big_test.list:`n" | Out-File $ResultsFile -Append

    $bigTest = Join-Path $TestFolder "big_test.list"
    if (Test-Path $bigTest) {
        foreach ($prog in $programs) {
            if (-not $prog.ExecCmd) { continue }

            $exeCmd = $prog.ExecCmd
            $outPath = Join-Path $TestFolder $prog.OutputFile

            Write-Host "[ScaleUp] Running $($prog.Name)..."
            Push-Location $SourceFolder
            $timeTaken = Measure-Command {
                & cmd /c "$exeCmd < `"$bigTest`" > `"$outPath`""
            }
            Pop-Location

            $sec = [Math]::Round($timeTaken.TotalSeconds, 3)
            $resultLine = "[ScaleUp][$($prog.Name)] completed in $sec seconds"
            Write-Host $resultLine
            $resultLine | Out-File $ResultsFile -Append
        }
    }
    else {
        Write-Host "big_test.list not found. Skipping scale-up test."
    }
}

Write-Host "`nAll tests completed. See $ResultsFile for details."
