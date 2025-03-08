import ast
import sys
import os
import glob
import re
from typing import List, Tuple, Dict, Set, Optional


class ImportModuleAnalyzer(ast.NodeVisitor):
    """AST visitor that finds calls to import_module and checks their arguments."""
    
    def __init__(self):
        self.violations = []  # List to store violations
    
    def visit_Call(self, node):
        """Visit a function call node in the AST."""
        # Check if this is a call to import_module
        if isinstance(node.func, ast.Name) and node.func.id == 'import_module':
            # Check if it has exactly one argument
            if len(node.args) != 1:
                self.violations.append((
                    node.lineno,
                    f"import_module call has {len(node.args)} arguments, expected exactly 1"
                ))
            # Check if the argument is the string "/imports.star"
            elif not (isinstance(node.args[0], ast.Constant) and 
                     isinstance(node.args[0].value, str) and 
                     node.args[0].value == "/imports.star"):
                self.violations.append((
                    node.lineno,
                    f"only /imports.star can be imported using import_module. Please use imports.load_module in other cases"
                ))
        
        # Continue visiting child nodes
        self.generic_visit(node)


class LoadModuleAnalyzer(ast.NodeVisitor):
    """
    AST visitor that tracks import_module assignments and verifies that
    load_module calls without package_id have valid relative paths.
    """
    
    def __init__(self):
        self.violations = []  # List to store violations
        self.import_vars = set()  # Variables assigned from import_module("/imports.star")
    
    def visit_Assign(self, node):
        """Visit assignment nodes to track import_module assignments."""
        # Check if this is an assignment from import_module("/imports.star")
        if (isinstance(node.value, ast.Call) and 
            isinstance(node.value.func, ast.Name) and 
            node.value.func.id == 'import_module' and
            len(node.value.args) == 1 and
            isinstance(node.value.args[0], ast.Constant) and
            isinstance(node.value.args[0].value, str) and
            node.value.args[0].value == "/imports.star"):
            
            # Add all target variables to our tracked set
            for target in node.targets:
                if isinstance(target, ast.Name):
                    self.import_vars.add(target.id)
        
        # Continue visiting child nodes
        self.generic_visit(node)
    
    def visit_Call(self, node):
        """Visit call nodes to check load_module calls."""
        # Check if this is a call to VARIABLE.load_module where VARIABLE is from import_module
        if (isinstance(node.func, ast.Attribute) and 
            node.func.attr == 'load_module' and
            isinstance(node.func.value, ast.Name) and
            node.func.value.id in self.import_vars):
            
            # Check if it has at least one argument (module_path)
            if len(node.args) < 1 and not any(kw.arg == 'module_path' for kw in node.keywords):
                self.violations.append((
                    node.lineno,
                    f"load_module call missing required module_path argument"
                ))
            else:
                # Check if package_id is provided (either as positional or keyword argument)
                has_package_id = False
                
                # Check for package_id in keyword arguments
                if any(kw.arg == 'package_id' for kw in node.keywords):
                    has_package_id = True
                
                # Check for package_id in positional arguments (if it's the second argument)
                elif len(node.args) >= 2:
                    has_package_id = True
                
                # If no package_id is provided, verify that module_path is a valid relative path
                if not has_package_id:
                    module_path = None
                    
                    # Get module_path from positional argument
                    if len(node.args) >= 1:
                        module_path_node = node.args[0]
                    # Or from keyword argument
                    else:
                        for kw in node.keywords:
                            if kw.arg == 'module_path':
                                module_path_node = kw.value
                                break
                    
                    # Verify the path if it's a string literal
                    if isinstance(module_path_node, ast.Constant) and isinstance(module_path_node.value, str):
                        module_path = module_path_node.value
                        if not self._is_valid_relative_path(module_path):
                            self.violations.append((
                                node.lineno,
                                f"load_module without package_id must use a valid relative path from the root dir, got '{module_path}'"
                            ))
                    else:
                        # Non-constant module_path can't be statically analyzed
                        self.violations.append((
                            node.lineno,
                            f"load_module path must be a string literal for static analysis"
                        ))
        
        # Continue visiting child nodes
        self.generic_visit(node)
    
    def _is_valid_relative_path(self, path: str) -> bool:
        """
        Check if a path is a valid relative path.
        
        A valid relative path:
        - Does not start with '/'
        - Does not contain '..' segments
        - Does not start with a drive letter (Windows)
        - Contains only valid path characters
        """
        if path.startswith('/'):
            return False
        
        if '..' in path.split('/'):
            return False
        
        # Check for Windows drive letter (e.g., C:)
        if re.match(r'^[a-zA-Z]:', path):
            return False
        
        # Check for valid path characters (simplified check)
        if re.search(r'[<>:"|?*]', path):
            return False
        
        return True


def analyze_file(file_path: str) -> List[Tuple[int, str]]:
    """
    Analyze a Python file for import_module and load_module calls.
    
    Args:
        file_path: Path to the Python file to analyze
        
    Returns:
        List of (line_number, violation_message) tuples
    """
    try:
        with open(file_path, 'r') as f:
            source = f.read()
        
        # Parse the source code into an AST
        tree = ast.parse(source, filename=file_path)
        
        # Run both analyzers
        violations = []
        
        # Check import_module calls
        import_analyzer = ImportModuleAnalyzer()
        import_analyzer.visit(tree)
        violations.extend(import_analyzer.violations)
        
        # Check load_module calls
        load_analyzer = LoadModuleAnalyzer()
        load_analyzer.visit(tree)
        violations.extend(load_analyzer.violations)
        
        # Sort violations by line number
        violations.sort(key=lambda v: v[0])
        
        return violations
    
    except Exception as e:
        return [(0, f"Error analyzing file: {str(e)}")]


def find_star_files(path: str) -> List[str]:
    """
    Find all *.star files in the given path recursively.
    
    Args:
        path: Directory path to search
        
    Returns:
        List of paths to *.star files
    """
    if os.path.isfile(path):
        return [path] if path.endswith('.star') else []
    
    star_files = []
    for root, _, _ in os.walk(path):
        star_files.extend(glob.glob(os.path.join(root, "*.star")))
    
    return star_files


def main():
    """Main entry point for the script."""
    if len(sys.argv) < 2:
        print("Usage: python imports.py <file_or_directory_path> [<file_or_directory_path> ...]")
        sys.exit(1)
    
    files_with_violations = 0
    total_files_analyzed = 0
    
    for path in sys.argv[1:]:
        # Find all .star files if path is a directory
        files_to_analyze = find_star_files(path)
        
        for file_path in files_to_analyze:
            total_files_analyzed += 1
            violations = analyze_file(file_path)
            
            if violations:
                files_with_violations += 1
                print(f"\nViolations in {file_path}:")
                for line, message in violations:
                    print(f"  Line {line}: {message}")
    
    print(f"\nAnalyzed {total_files_analyzed} .star files")
    
    if files_with_violations:
        print(f"Found violations in {files_with_violations} file(s)")
        sys.exit(1)
    else:
        print("No violations found")
        sys.exit(0)


if __name__ == "__main__":
    main()
