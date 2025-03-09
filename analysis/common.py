"""
Common utilities for Starlark code analysis.

This module contains shared functionality used by both imports.py and calls.py.
"""

import ast
import os
import sys
from typing import List, Tuple, Dict, Any, Optional, Callable

# Import BaseVisitor for verbosity control
try:
    from analysis.visitors.base_visitor import BaseVisitor
except ImportError:
    from visitors.base_visitor import BaseVisitor

def set_verbose(verbose: bool):
    """
    Set the verbosity for all analysis tools.
    
    This is the single function that should be used to control verbosity
    throughout the codebase.
    """
    BaseVisitor.set_verbose(verbose)

def debug_print(*args, **kwargs):
    """
    Print debug messages only when verbose mode is enabled.
    
    This is a convenience function that uses BaseVisitor's verbosity setting.
    """
    if BaseVisitor.verbose:
        print(*args, **kwargs)

def find_star_files(path: str) -> List[str]:
    """
    Find all .star files in a directory or return the path if it's a file.
    
    Args:
        path: Path to a file or directory
        
    Returns:
        List of paths to .star files
    """
    debug_print(f"Looking for .star files in: {path}")
    
    # Handle absolute and relative paths
    path = os.path.abspath(path)
    debug_print(f"Absolute path: {path}")
    
    if os.path.isfile(path):
        debug_print(f"Path is a file: {path}")
        if path.endswith('.star'):
            debug_print(f"File has .star extension, returning: {path}")
            return [path]
        else:
            debug_print(f"File does not have .star extension, ignoring: {path}")
            return []
    
    # If the path is a basename (just a filename without directory)
    # and it exists in the current directory, use it
    if not os.path.dirname(path) and os.path.isfile(os.path.join(os.getcwd(), path)):
        full_path = os.path.join(os.getcwd(), path)
        debug_print(f"Found file in current directory: {full_path}")
        if full_path.endswith('.star'):
            return [full_path]
        else:
            return []
    
    # If we get here, the path is a directory or doesn't exist
    if not os.path.isdir(path):
        debug_print(f"Path is not a file or directory: {path}")
        return []
    
    debug_print(f"Path is a directory, walking: {path}")
    result = []
    
    for root, _, files in os.walk(path):
        for file in files:
            if file.endswith('.star'):
                file_path = os.path.join(root, file)
                debug_print(f"Found .star file: {file_path}")
                result.append(file_path)
    
    debug_print(f"Found {len(result)} .star files")
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

def parse_file(file_path: str) -> ast.Module:
    """
    Parse a file into an AST.
    
    Args:
        file_path: Path to the file to parse
        
    Returns:
        AST module node
    """
    with open(file_path, 'r') as f:
        source = f.read()
    
    return ast.parse(source, filename=file_path)

def run_analysis(
    path: str, 
    analyze_func: Callable, 
    verbose: bool = False,
    extra_args: Dict[str, Any] = None
) -> bool:
    """
    Run an analysis function on all .star files in a path.
    
    Args:
        path: Path to a file or directory
        analyze_func: Function to call on each file
        verbose: Whether to enable verbose output
        extra_args: Additional arguments to pass to the analyze function
        
    Returns:
        True if no violations were found, False otherwise
    """
    # Note: verbose flag should be set before calling this function
    # But we'll set it here as well for safety
    BaseVisitor.set_verbose(verbose)
    
    # Find all .star files
    star_files = find_star_files(path)
    
    # Analyze each file
    all_violations = []
    
    for file_path in star_files:
        args = {"file_path": file_path}
        if extra_args:
            args.update(extra_args)
        
        violations = analyze_func(**args)
        if violations:
            for lineno, message in violations:
                print(f"{file_path}:{lineno}: {message}")
            all_violations.extend([(file_path, lineno, message) for lineno, message in violations])
    
    # Print summary
    print(f"\nAnalyzed {len(star_files)} .star files")
    if all_violations:
        print(f"Found violations in {len(set(v[0] for v in all_violations))} file(s)")
        return False
    else:
        print("No violations found")
        return True 