import os
import subprocess
import sys

def run_tests():
    print("Running Luau Unit Tests...")
    test_dir = os.path.join("Modules", "Core", "Tests")
    
    if not os.path.exists(test_dir):
        print("No test directory found.")
        return True
        
    test_files = [f for f in os.listdir(test_dir) if f.endswith(".test.luau") or f.endswith(".test.lua")]
    
    if not test_files:
        print("No test files found.")
        return True
        
    all_passed = True
    for test_file in sorted(test_files):
        test_path = os.path.join(test_dir, test_file)
        print(f"Executing: {test_file}")
        
        # Execute using luau CLI
        try:
            result = subprocess.run(
                ["luau", test_path],
                capture_output=True,
                text=True,
                check=False
            )
            
            # Print output
            if result.stdout:
                print(result.stdout.strip())
            if result.stderr:
                print(result.stderr.strip(), file=sys.stderr)
                
            if result.returncode != 0:
                print(f"[-] {test_file} failed with exit code {result.returncode}")
                all_passed = False
            else:
                print(f"[+] {test_file} passed")
        except Exception as e:
            print(f"[-] Error running {test_file}: {e}")
            all_passed = False
            
    return all_passed

if __name__ == "__main__":
    success = run_tests()
    if not success:
        sys.exit(1)
    else:
        sys.exit(0)
