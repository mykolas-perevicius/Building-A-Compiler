#!/usr/bin/env python3
import subprocess
import time
import os
import sys
import glob

# Set up the project root and test directory.
ROOT_DIR = os.path.abspath(os.path.dirname(__file__))
TEST_DIR = os.path.join(ROOT_DIR, "test")

# Add NASM to the PATH.
nasm_dir = r"C:\Users\miciu\AppData\Local\bin\NASM"
os.environ["PATH"] += os.pathsep + nasm_dir

# --------------------------------------------------------------------
# NOTE:
# The previous version directly ran a Kotlin compile command at the
# top of the file. This has been removed so that all implementations,
# including Kotlin, are compiled uniformly within the implementations loop.
# --------------------------------------------------------------------

# Define all implementations.
# For each implementation, we specify:
# - source: the filename of the implementation (for reference)
# - compile: either None (if no compilation is needed) or a command (or list of commands) to compile it
# - run: the command to run the resulting executable/script.
#
# The Kotlin implementation now uses "kotlinc.bat" explicitly.
implementations = {
    "Kotlin": {
         "source": "rosetta.kt",
         "compile": [
             "kotlinc.bat",
             os.path.join(ROOT_DIR, "rosetta.kt"),
             "-include-runtime",
             "-d",
             os.path.join(ROOT_DIR, "rosetta_kt.jar")
         ],
         "run": ["java", "-jar", os.path.join(ROOT_DIR, "rosetta_kt.jar")]
    },
    "Python": {
         "source": "rosetta.py",
         "compile": None,
         "run": ["python", os.path.join(ROOT_DIR, "rosetta.py")]
    },
    "Rust": {
         "source": "rosetta.rs",
         "compile": [
             "rustc",
             os.path.join(ROOT_DIR, "rosetta.rs"),
             "-o",
             os.path.join(ROOT_DIR, "rosetta_rs.exe")
         ],
         "run": [os.path.join(ROOT_DIR, "rosetta_rs.exe")]
    },
    "Scala": {
         "source": "Rosetta.scala",
         "compile": [
             "scalac",
             os.path.join(ROOT_DIR, "Rosetta.scala")
         ],
         "run": ["scala", "-cp", ROOT_DIR, "Rosetta"]
    },
}

def find_test_cases():
    """
    Finds all test cases in TEST_DIR.
    Each test case consists of a .list file (input) and, if present, a corresponding .answer file (expected output).
    """
    test_cases = []
    list_files = glob.glob(os.path.join(TEST_DIR, "*.list"))
    for in_file in list_files:
        base = os.path.splitext(os.path.basename(in_file))[0]
        answer_file = os.path.join(TEST_DIR, base + ".answer")
        if os.path.exists(answer_file):
            test_cases.append((in_file, answer_file))
        else:
            test_cases.append((in_file, None))
    return sorted(test_cases)

def compile_solution(name, impl):
    """
    Compiles the solution if a compile command is provided.
    If the compile command is a list of lists, each command is executed sequentially.
    """
    compile_cmd = impl["compile"]
    if compile_cmd is None:
        return
    # Check if we have multiple commands.
    if isinstance(compile_cmd[0], list):
        for cmd in compile_cmd:
            print(f"[{name}] Running compile command: {' '.join(cmd)}")
            try:
                subprocess.run(cmd, capture_output=True, text=True, check=True)
            except subprocess.CalledProcessError as e:
                print(f"Compilation failed for {name} while running: {' '.join(cmd)}")
                print(e.stdout)
                print(e.stderr)
                sys.exit(1)
    else:
        print(f"[{name}] Running compile command: {' '.join(compile_cmd)}")
        try:
            subprocess.run(compile_cmd, capture_output=True, text=True, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Compilation failed for {name}:")
            print(e.stdout)
            print(e.stderr)
            sys.exit(1)
    print(f"[{name}] Compilation successful.")

def run_test(impl_run_cmd, input_path, expected_path):
    """
    Runs a single test case using the specified run command.
    Returns a tuple: (passed, elapsed_time, output, expected).
    """
    with open(input_path, "r") as fin:
        start_time = time.time()
        try:
            result = subprocess.run(impl_run_cmd, stdin=fin, capture_output=True, text=True, timeout=5)
        except subprocess.TimeoutExpired:
            return (False, None, "Timed out", None)
        elapsed = time.time() - start_time

    output = result.stdout.strip()
    if expected_path and os.path.exists(expected_path):
        with open(expected_path, "r") as fexp:
            expected = fexp.read().strip()
    else:
        expected = None
    passed = (expected is None or output == expected)
    return (passed, elapsed, output, expected)

def main():
    test_cases = find_test_cases()
    print("Found test cases:")
    for in_file, _ in test_cases:
        print(" -", os.path.basename(in_file))

    # Compile each implementation that requires compilation.
    for name, impl in implementations.items():
        compile_solution(name, impl)

    # Run every implementation on every test case.
    for name, impl in implementations.items():
        print("\n==============================")
        print(f"Running tests for {name} ({impl['source']}):")
        for (in_file, ans_file) in test_cases:
            base_test = os.path.basename(in_file)
            passed, elapsed, output, expected = run_test(impl["run"], in_file, ans_file)
            if passed:
                print(f"  [PASS] {base_test} in {elapsed:.3f} seconds.")
            else:
                print(f"  [FAIL] {base_test} in {elapsed:.3f} seconds.")
                print("    Expected:")
                print("    ---------")
                print(expected)
                print("    Got:")
                print("    ---------")
                print(output)
    print("\nAll tests completed.")

if __name__ == "__main__":
    main()
