import os
import subprocess

# Define paths
base_dir = "provided"
rosetta_script = os.path.join(os.getcwd(), "rosetta.py")  # Use absolute path


# Collect test cases and expected outputs
test_cases = []
for file in os.listdir(base_dir):
    if file.endswith(".list"):
        test_name = file[:-5]  # Remove ".list" extension
        expected_file = os.path.join(base_dir, f"{test_name}.answer")
        if os.path.exists(expected_file):  # Only add if .answer file exists
            test_cases.append({
                "name": test_name,
                "input": os.path.join(base_dir, f"{test_name}.list"),
                "expected": expected_file
            })

# Function to run a test
def run_test(test):
    with open(test["input"], "r") as input_file:
        input_content = input_file.read()
        process = subprocess.run(
            ["python3", rosetta_script],
            input=input_content,
            capture_output=True,
            text=True
        )
    actual_output = process.stdout.strip()
    debug_output = process.stderr.strip()
    with open(test["expected"], "r") as expected_file:
        expected_output = expected_file.read().strip()
    passed = actual_output == expected_output
    return {
        "test_name": test["name"],
        "actual_output": actual_output,
        "expected_output": expected_output,
        "debug_output": debug_output,
        "passed": passed
    }

# Run all tests
results = [run_test(test) for test in test_cases]

# Print summary
print("Test Results:")
print("-" * 50)
for result in results:
    print(f"Test: {result['test_name']}")
    print(f"  Passed: {'Yes' if result['passed'] else 'No'}")
    print(f"  Expected:\n{result['expected_output']}")
    print(f"  Actual:\n{result['actual_output']}")
    print(f"  Debug Logs:\n{result['debug_output']}")
    print("-" * 50)

# Save results to a file
results_file = os.path.join(base_dir, "test_results.txt")
with open(results_file, "w") as f:
    for result in results:
        f.write(f"Test: {result['test_name']}\n")
        f.write(f"  Passed: {'Yes' if result['passed'] else 'No'}\n")
        f.write(f"  Expected:\n{result['expected_output']}\n")
        f.write(f"  Actual:\n{result['actual_output']}\n")
        f.write(f"  Debug Logs:\n{result['debug_output']}\n")
        f.write("-" * 50 + "\n")
print(f"Test results saved to {results_file}")
