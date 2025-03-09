"""
Analyzes function calls in Starlark files.

This module analyzes function calls in Starlark files to ensure they are valid.
"""

import sys
import os
import ast
import re
from typing import List, Tuple, Dict, Set, Optional, NamedTuple, Any

# Handle imports for both module and script execution
try:
    # When run as a module
    from analysis.visitors.common import FunctionSignature, ImportInfo
    from analysis.visitors.function_collector import FunctionCollector
    from analysis.visitors.import_collector import ImportCollector
    from analysis.visitors.call_analyzer import CallAnalyzer
    from analysis.visitors.base_visitor import debug_print, VERBOSE
except ModuleNotFoundError:
    # When run as a script
    from visitors.common import FunctionSignature, ImportInfo
    from visitors.function_collector import FunctionCollector
    from visitors.import_collector import ImportCollector
    from visitors.call_analyzer import CallAnalyzer
    from visitors.base_visitor import debug_print, VERBOSE


def analyze_file(file_path: str, all_functions: Dict[str, Dict[str, FunctionSignature]], module_to_file: Dict[str, str]) -> Tuple[Dict[str, FunctionSignature], List[Tuple[int, str]]]:
    """
    Analyze a file for function definitions and calls.
    
    Args:
        file_path: Path to the file to analyze
        all_functions: Dictionary mapping file paths to their function definitions
        module_to_file: Dictionary mapping module paths to file paths
        
    Returns:
        Tuple of (functions defined in this file, violations found)
    """
    try:
        debug_print(f"Analyzing calls in file: {file_path}")
        with open(file_path, 'r') as f:
            source = f.read()
        
        # Parse the source code into an AST
        tree = ast.parse(source, filename=file_path)
        
        # First pass: collect function definitions
        collector = FunctionCollector(file_path)
        collector.visit(tree)
        
        # Collect import information
        import_collector = ImportCollector()
        import_collector.visit(tree)
        
        # Second pass: analyze function calls
        analyzer = CallAnalyzer(
            file_path=file_path,
            local_functions=collector.functions,
            imports=import_collector.imports,
            all_functions=all_functions,
            module_to_file=module_to_file,
            imports_derived_vars=import_collector.imports_derived_vars,
            import_module_vars=import_collector.import_module_vars
        )
        analyzer.visit(tree)
        
        return collector.functions, analyzer.violations
    
    except Exception as e:
        print(f"Error analyzing file {file_path}: {str(e)}")
        return {}, [(0, f"Error analyzing file {file_path}: {str(e)}")]


def find_star_files(path: str) -> List[str]:
    """Find all .star files in a directory or return the path if it's a file."""
    if os.path.isfile(path):
        if path.endswith('.star'):
            return [path]
        else:
            return []
    
    result = []
    debug_print(f"Searching for .star files in {path}")
    
    for root, _, files in os.walk(path):
        for file in files:
            if file.endswith('.star'):
                result.append(os.path.join(root, file))
    
    return result


def main():
    """Main entry point for the script."""
    # Parse command line arguments
    if len(sys.argv) < 2:
        print("Usage: python calls.py <path>")
        sys.exit(1)
    
    path = sys.argv[1]
    
    # Find all .star files
    star_files = find_star_files(path)
    print(f"Found {len(star_files)} .star files to analyze")
    
    # First pass: collect function definitions from all files
    print("First pass: collecting function definitions...")
    all_functions = {}  # file_path -> {function_name -> FunctionSignature}
    module_to_file = {}  # module_path -> file_path
    
    for file_path in star_files:
        # Convert file path to module path
        module_path = file_path
        if module_path.startswith('./'):
            module_path = module_path[2:]
        module_to_file[module_path] = file_path
        
        # Also add without .star extension
        if module_path.endswith('.star'):
            module_path_no_ext = module_path[:-5]
            module_to_file[module_path_no_ext] = file_path
    
    for file_path in star_files:
        try:
            with open(file_path, 'r') as f:
                source = f.read()
            
            # Parse the source code into an AST
            tree = ast.parse(source, filename=file_path)
            
            # Collect function definitions
            collector = FunctionCollector(file_path)
            collector.visit(tree)
            
            # Add to all_functions
            all_functions[file_path] = collector.functions
        
        except Exception as e:
            print(f"Error collecting functions from {file_path}: {str(e)}")
    
    # Second pass: analyze function calls
    print("\nSecond pass: analyzing function calls...")
    all_violations = []
    
    for file_path in star_files:
        _, violations = analyze_file(file_path, all_functions, module_to_file)
        if violations:
            for lineno, message in violations:
                print(f"{file_path}:{lineno}: {message}")
            all_violations.extend([(file_path, lineno, message) for lineno, message in violations])
    
    # Print summary
    print(f"\nAnalysis complete: found {len(all_violations)} violations in {len(set(v[0] for v in all_violations))} files")
    
    # Exit with error code if violations were found
    if all_violations:
        sys.exit(1)
    else:
        print("No violations found")


if __name__ == "__main__":
    main()
