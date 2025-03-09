"""
Analyzes imports in Starlark files.

This module analyzes imports in Starlark files to ensure they follow the correct conventions.
"""

import ast
import sys
import os
import glob
import re
from typing import List, Tuple, Dict, Set, Optional

# Handle imports for both module and script execution
try:
    # When run as a module
    from analysis.visitors.import_module_analyzer import ImportModuleAnalyzer, IMPORTS_STAR_FILENAME, IMPORTS_STAR_LOCATOR
    from analysis.visitors.load_module_analyzer import LoadModuleAnalyzer
except ModuleNotFoundError:
    # When run as a script
    from visitors.import_module_analyzer import ImportModuleAnalyzer, IMPORTS_STAR_FILENAME, IMPORTS_STAR_LOCATOR
    from visitors.load_module_analyzer import LoadModuleAnalyzer


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
        with open(file_path, 'r') as f:
            source = f.read()
        
        # Parse the source code into an AST
        tree = ast.parse(source, filename=file_path)
        
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


def find_star_files(path: str) -> List[str]:
    """Find all .star files in a directory or return the path if it's a file."""
    if os.path.isfile(path):
        if path.endswith('.star'):
            return [path]
        else:
            return []
    
    result = []
    
    for root, _, files in os.walk(path):
        for file in files:
            if file.endswith('.star'):
                result.append(os.path.join(root, file))
    
    return result


def find_workspace_root(start_path: str = None) -> str:
    """
    Find the workspace root directory.
    
    The workspace root is determined by looking for a directory that contains
    a main.star file or a .git directory.
    
    Args:
        start_path: Path to start the search from (defaults to current directory)
        
    Returns:
        Absolute path to the workspace root directory
    """
    if start_path is None:
        start_path = os.getcwd()
    
    # Convert to absolute path
    start_path = os.path.abspath(start_path)
    
    # If the start path is a file, use its directory
    if os.path.isfile(start_path):
        start_path = os.path.dirname(start_path)
    
    # Walk up the directory tree looking for main.star or .git
    current_path = start_path
    while current_path != os.path.dirname(current_path):  # Stop at root directory
        # Check if this directory contains main.star or .git
        if os.path.isfile(os.path.join(current_path, 'main.star')) or os.path.isdir(os.path.join(current_path, '.git')):
            return current_path
        
        # Move up one directory
        current_path = os.path.dirname(current_path)
    
    # If we couldn't find a workspace root, use the start path
    return start_path


def main():
    """Main entry point for the script."""
    # Parse command line arguments
    if len(sys.argv) < 2:
        print("Usage: python imports.py <path>")
        sys.exit(1)
    
    path = sys.argv[1]
    
    # Find the workspace root
    workspace_root = find_workspace_root(path)
    print(f"Using workspace root: {workspace_root}")
    
    # Find all .star files
    star_files = find_star_files(path)
    
    # Analyze each file
    all_violations = []
    
    for file_path in star_files:
        violations = analyze_file(file_path, workspace_root)
        if violations:
            for lineno, message in violations:
                print(f"{file_path}:{lineno}: {message}")
            all_violations.extend([(file_path, lineno, message) for lineno, message in violations])
    
    # Print summary
    print(f"\nAnalyzed {len(star_files)} .star files")
    if all_violations:
        print(f"Found violations in {len(set(v[0] for v in all_violations))} file(s)")
        sys.exit(1)
    else:
        print("No violations found")


if __name__ == "__main__":
    main()
