"""
Analyzes imports in Starlark files.

This module analyzes imports in Starlark files to ensure they follow the correct conventions.
"""

import ast
import sys
import os
import argparse
from typing import List, Tuple, Dict, Set, Optional

# Handle imports for both module and script execution
try:
    # When run as a module
    from analysis.visitors.import_module_analyzer import ImportModuleAnalyzer, IMPORTS_STAR_FILENAME, IMPORTS_STAR_LOCATOR
    from analysis.visitors.load_module_analyzer import LoadModuleAnalyzer
    from analysis.visitors.base_visitor import BaseVisitor
    from analysis.common import find_star_files, find_workspace_root, parse_file, run_analysis, debug_print
except ModuleNotFoundError:
    # When run as a script
    from visitors.import_module_analyzer import ImportModuleAnalyzer, IMPORTS_STAR_FILENAME, IMPORTS_STAR_LOCATOR
    from visitors.load_module_analyzer import LoadModuleAnalyzer
    from visitors.base_visitor import BaseVisitor
    from common import find_star_files, find_workspace_root, parse_file, run_analysis, debug_print


def analyze_file(file_path: str, workspace_root: str = None, check_file_exists: bool = True) -> List[Tuple[int, str]]:
    """
    Analyze a file for import violations.
    
    Args:
        file_path: Path to the file to analyze
        workspace_root: Root directory of the workspace
        check_file_exists: Whether to check if imported modules exist
        
    Returns:
        List of (line number, violation message) tuples
    """
    try:
        # Parse the source code into an AST
        tree = parse_file(file_path)
        
        # Check import_module calls
        import_module_analyzer = ImportModuleAnalyzer(file_path)
        import_module_analyzer.visit(tree)
        
        # Check load_module calls
        load_module_analyzer = LoadModuleAnalyzer(file_path, workspace_root, check_file_exists)
        load_module_analyzer.visit(tree)
        
        # Combine violations from both analyzers
        violations = import_module_analyzer.violations + load_module_analyzer.violations
        
        # Sort violations by line number
        violations.sort(key=lambda v: v[0])
        
        return violations
    
    except Exception as e:
        print(f"Error analyzing file {file_path}: {str(e)}")
        return [(0, f"Error analyzing file {file_path}: {str(e)}")]


def main():
    """Main entry point for the script."""
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Analyze imports in Starlark files")
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
    
    # Run the analysis
    extra_args = {"workspace_root": workspace_root}
    success = run_analysis(args.path, analyze_file, args.verbose, extra_args)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
