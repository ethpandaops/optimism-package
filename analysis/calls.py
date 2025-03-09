"""
Analyzes function calls in Starlark files.

This module analyzes function calls in Starlark files to ensure they are valid.
"""

import sys
import os
import ast
import argparse
from typing import List, Tuple, Dict, Set, Optional, Any

# Handle imports for both module and script execution
try:
    # When run as a module
    from analysis.visitors.common import FunctionSignature, ImportInfo
    from analysis.visitors.function_collector import FunctionCollector
    from analysis.visitors.import_collector import ImportCollector
    from analysis.visitors.call_analyzer import CallAnalyzer
    from analysis.visitors.base_visitor import BaseVisitor
    from analysis.common import find_star_files, parse_file, run_analysis, debug_print, find_workspace_root
except ModuleNotFoundError:
    # When run as a script
    from visitors.common import FunctionSignature, ImportInfo
    from visitors.function_collector import FunctionCollector
    from visitors.import_collector import ImportCollector
    from visitors.call_analyzer import CallAnalyzer
    from visitors.base_visitor import BaseVisitor
    from common import find_star_files, parse_file, run_analysis, debug_print, find_workspace_root


def analyze_file(file_path: str, all_functions: Dict[str, Dict[str, FunctionSignature]] = None, module_to_file: Dict[str, str] = None, workspace_root: str = None) -> List[Tuple[int, str]]:
    """
    Analyze a file for function definitions and calls.
    
    Args:
        file_path: Path to the file to analyze
        all_functions: Dictionary mapping file paths to their function definitions
        module_to_file: Dictionary mapping module paths to file paths
        workspace_root: Root directory of the workspace
        
    Returns:
        List of violations found
    """
    try:
        debug_print(f"Analyzing calls in file: {file_path}")
        
        # Initialize dictionaries if not provided
        if all_functions is None:
            all_functions = {}
        if module_to_file is None:
            module_to_file = {}
        
        # If workspace_root is not provided, try to determine it
        if workspace_root is None:
            try:
                from analysis.common import find_workspace_root
                workspace_root = find_workspace_root(file_path)
            except ImportError:
                from common import find_workspace_root
                workspace_root = find_workspace_root(file_path)
            
            debug_print(f"Using workspace root: {workspace_root}")
        
        # Parse the source code into an AST
        tree = parse_file(file_path)
        
        # First pass: collect function definitions
        function_collector = FunctionCollector(file_path)
        function_collector.visit(tree)
        local_functions = function_collector.functions
        
        # Store functions in the global dictionary
        all_functions[file_path] = local_functions
        
        # Second pass: collect imports
        import_collector = ImportCollector()
        import_collector.visit(tree)
        imports = import_collector.imports
        import_module_vars = import_collector.import_module_vars
        imports_derived_vars = import_collector.imports_derived_vars
        
        # Update module_to_file mapping
        for var_name, import_info in imports.items():
            if import_info.package_id is None and import_info.module_path:
                module_path = import_info.module_path
                
                # Remove leading slash if present
                if module_path.startswith('/'):
                    module_path = module_path[1:]
                
                # Resolve the module path to an absolute file path
                resolved_path = os.path.join(workspace_root, module_path)
                
                # Check if the file exists
                if os.path.isfile(resolved_path):
                    debug_print(f"Found module {module_path} at {resolved_path}")
                    
                    # Store the mapping
                    module_to_file[module_path] = resolved_path
                else:
                    debug_print(f"Could not find file for module {module_path} at {resolved_path}")
        
        # Third pass: analyze function calls
        call_analyzer = CallAnalyzer(
            file_path,
            local_functions,
            imports,
            all_functions,
            module_to_file,
            imports_derived_vars,
            import_module_vars
        )
        call_analyzer.visit(tree)
        
        return call_analyzer.violations
    
    except Exception as e:
        print(f"Error analyzing file {file_path}: {str(e)}")
        import traceback
        traceback.print_exc()
        return [(0, f"Error analyzing file {file_path}: {str(e)}")]


def main():
    """Main entry point for the script."""
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Analyze function calls in Starlark files")
    parser.add_argument("path", nargs="?", default=".", help="Path to the directory or file to analyze")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output")
    args = parser.parse_args()
    
    # Set verbose flag early
    BaseVisitor.set_verbose(args.verbose)
    
    if args.verbose:
        print(f"Analyzing path: {args.path}")
        print(f"Verbose mode: {args.verbose}")
    
    # Find the workspace root
    workspace_root = find_workspace_root(args.path)
    if args.verbose:
        print(f"Using workspace root: {workspace_root}")
    
    # Find all .star files
    star_files = find_star_files(args.path)
    if args.verbose:
        print(f"Found {len(star_files)} .star files to analyze")
    
    # First pass: collect all function definitions
    print("First pass: collecting function definitions...")
    all_functions = {}  # file_path -> {function_name -> FunctionSignature}
    module_to_file = {}  # module_path -> file_path
    
    # Run the analysis
    extra_args = {
        "all_functions": all_functions,
        "module_to_file": module_to_file,
        "workspace_root": workspace_root
    }
    
    print("\nSecond pass: analyzing function calls...")
    success = run_analysis(args.path, analyze_file, args.verbose, extra_args)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
