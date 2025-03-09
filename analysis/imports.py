import ast
import sys
import os
import glob
import re
from typing import List, Tuple, Dict, Set, Optional

# Constants
IMPORTS_STAR_FILENAME = "imports.star"
IMPORT_MODULE_FUNC = "import_module"
LOAD_MODULE_FUNC = "load_module"
MODULE_PATH_ARG = "module_path"
PACKAGE_ID_ARG = "package_id"
STAR_FILE_EXTENSION = ".star"

IMPORTS_STAR_LOCATOR = "/{0}".format(IMPORTS_STAR_FILENAME)

class ImportModuleAnalyzer(ast.NodeVisitor):
    """AST visitor that finds calls to import_module and checks their arguments."""
    
    def __init__(self):
        self.violations = []  # List to store violations
    
    def visit_Call(self, node):
        """Visit a function call node in the AST."""
        # Check if this is a call to import_module
        if isinstance(node.func, ast.Name) and node.func.id == IMPORT_MODULE_FUNC:
            # Check if it has exactly one argument
            if len(node.args) != 1:
                self.violations.append((
                    node.lineno,
                    f"{IMPORT_MODULE_FUNC} call has {len(node.args)} arguments, expected exactly 1"
                ))
            # Check if the argument is the string "/imports.star"
            elif not (isinstance(node.args[0], ast.Constant) and 
                     isinstance(node.args[0].value, str) and 
                     node.args[0].value == IMPORTS_STAR_LOCATOR):
                self.violations.append((
                    node.lineno,
                    f"only {IMPORTS_STAR_LOCATOR} can be imported using {IMPORT_MODULE_FUNC}. Please use imports.{LOAD_MODULE_FUNC} in other cases"
                ))
        
        # Continue visiting child nodes
        self.generic_visit(node)
    
    def visit_Assign(self, node):
        """Visit assignment nodes to check that import_module results are stored in private variables."""
        # Check if this is an assignment from import_module
        if (isinstance(node.value, ast.Call) and 
            isinstance(node.value.func, ast.Name) and 
            node.value.func.id == IMPORT_MODULE_FUNC):
            
            # Check that all target variables start with underscore
            for target in node.targets:
                if isinstance(target, ast.Name) and not target.id.startswith('_'):
                    self.violations.append((
                        node.lineno,
                        f"Results of {IMPORT_MODULE_FUNC} should be stored in private variables (starting with '_') to keep imports scoped to the current file"
                    ))
        
        # Continue visiting child nodes
        self.generic_visit(node)


class LoadModuleAnalyzer(ast.NodeVisitor):
    """
    AST visitor that tracks import_module assignments and verifies that
    load_module calls without package_id have valid relative paths.
    """
    
    def __init__(self, file_path: str, workspace_root: str = None, check_file_exists: bool = True):
        self.violations = []  # List to store violations
        self.import_vars = set()  # Variables assigned from import_module("/imports.star")
        self.file_path = file_path
        self.workspace_root = workspace_root or os.getcwd()
        self.check_file_exists = check_file_exists
        self.is_imports_star = os.path.basename(file_path) == IMPORTS_STAR_FILENAME
    
    def visit_Assign(self, node):
        """Visit assignment nodes to track import_module assignments and check load_module assignments."""
        # Check if this is an assignment from import_module("/imports.star")
        if (isinstance(node.value, ast.Call) and 
            isinstance(node.value.func, ast.Name) and 
            node.value.func.id == IMPORT_MODULE_FUNC and
            len(node.value.args) == 1 and
            isinstance(node.value.args[0], ast.Constant) and
            isinstance(node.value.args[0].value, str) and
            node.value.args[0].value == IMPORTS_STAR_LOCATOR):
            
            # Add all target variables to our tracked set
            for target in node.targets:
                if isinstance(target, ast.Name):
                    self.import_vars.add(target.id)
        
        # Check if this is an assignment from load_module
        elif (isinstance(node.value, ast.Call) and 
              isinstance(node.value.func, ast.Attribute) and 
              node.value.func.attr == LOAD_MODULE_FUNC and
              isinstance(node.value.func.value, ast.Name) and
              node.value.func.value.id in self.import_vars):
            
            # Skip check for imports.star file
            if not self.is_imports_star:
                # Check that all target variables start with underscore
                for target in node.targets:
                    if isinstance(target, ast.Name) and not target.id.startswith('_'):
                        self.violations.append((
                            node.lineno,
                            f"Results of {LOAD_MODULE_FUNC} should be stored in private variables (starting with '_') to keep imports scoped to the current file"
                        ))
        
        # Continue visiting child nodes
        self.generic_visit(node)
    
    def visit_Call(self, node):
        """Visit call nodes to check load_module calls."""
        # Check if this is a call to VARIABLE.load_module where VARIABLE is from import_module
        if (isinstance(node.func, ast.Attribute) and 
            node.func.attr == LOAD_MODULE_FUNC and
            isinstance(node.func.value, ast.Name) and
            node.func.value.id in self.import_vars):
            
            # Check if it has at least one argument (module_path)
            if len(node.args) < 1 and not any(kw.arg == MODULE_PATH_ARG for kw in node.keywords):
                self.violations.append((
                    node.lineno,
                    f"{LOAD_MODULE_FUNC} call missing required {MODULE_PATH_ARG} argument"
                ))
            else:
                # Check if package_id is provided (either as positional or keyword argument)
                has_package_id = False
                
                # Check for package_id in keyword arguments
                if any(kw.arg == PACKAGE_ID_ARG for kw in node.keywords):
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
                            if kw.arg == MODULE_PATH_ARG:
                                module_path_node = kw.value
                                break
                    
                    # Verify the path if it's a string literal
                    if isinstance(module_path_node, ast.Constant) and isinstance(module_path_node.value, str):
                        module_path = module_path_node.value
                        if not self._is_valid_relative_path(module_path):
                            self.violations.append((
                                node.lineno,
                                f"{LOAD_MODULE_FUNC} without {PACKAGE_ID_ARG} must use a valid relative path, got '{module_path}'"
                            ))
                        else:
                            # Check if the module actually exists
                            if self.check_file_exists and not self._module_exists(module_path):
                                self.violations.append((
                                    node.lineno,
                                    f"{LOAD_MODULE_FUNC} references non-existent module: '{module_path}'"
                                ))
                    else:
                        # Non-constant module_path can't be statically analyzed
                        self.violations.append((
                            node.lineno,
                            f"{LOAD_MODULE_FUNC} path must be a string literal for static analysis"
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
    
    def _module_exists(self, module_path: str) -> bool:
        """
        Check if a module exists in the filesystem.
        
        Args:
            module_path: The module path to check
            
        Returns:
            True if the module exists, False otherwise
        """
        # Remove leading slash if present
        if module_path.startswith('/'):
            module_path = module_path[1:]
        
        # If the path doesn't end with .star, add it
        if not module_path.endswith(STAR_FILE_EXTENSION):
            module_path += STAR_FILE_EXTENSION
        
        # Only check relative to the workspace root
        workspace_path = os.path.normpath(os.path.join(self.workspace_root, module_path))
        
        # For debugging, print the path we tried
        if not os.path.isfile(workspace_path):
            print(f"DEBUG: Module not found: {module_path}")
            print(f"  Tried path: {workspace_path}")
        
        return os.path.isfile(workspace_path)


def analyze_file(file_path: str, workspace_root: str = None, check_file_exists: bool = True) -> List[Tuple[int, str]]:
    """
    Analyze a Python file for import_module and load_module calls.
    
    Args:
        file_path: Path to the Python file to analyze
        workspace_root: Root directory of the workspace
        check_file_exists: Whether to check if imported modules exist
        
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
        
        # Check if this is the imports.star file
        is_imports_star = os.path.basename(file_path) == IMPORTS_STAR_FILENAME
        
        # Check import_module calls (skip for imports.star file)
        if not is_imports_star:
            import_analyzer = ImportModuleAnalyzer()
            import_analyzer.visit(tree)
            violations.extend(import_analyzer.violations)
        
        # Check load_module calls
        load_analyzer = LoadModuleAnalyzer(file_path, workspace_root, check_file_exists)
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
        return [path] if path.endswith(STAR_FILE_EXTENSION) else []
    
    star_files = []
    for root, _, _ in os.walk(path):
        star_files.extend(glob.glob(os.path.join(root, f"*{STAR_FILE_EXTENSION}")))
    
    return star_files


def find_workspace_root(start_path: str = None) -> str:
    """
    Find the workspace root by looking for the src directory.
    
    Args:
        start_path: Path to start the search from
        
    Returns:
        The workspace root path
    """
    if start_path is None:
        start_path = os.getcwd()
    
    # If the current directory contains a src directory, it's the workspace root
    if os.path.isdir(os.path.join(start_path, 'src')):
        return start_path
    
    # If we're in the src directory, the parent is the workspace root
    if os.path.basename(start_path) == 'src' and os.path.isdir(start_path):
        return os.path.dirname(start_path)
    
    # If we're in a subdirectory of src, navigate up to find the workspace root
    parent = os.path.dirname(start_path)
    if parent == start_path:  # We've reached the filesystem root
        return start_path
    
    return find_workspace_root(parent)


def main():
    """Main entry point for the script."""
    if len(sys.argv) < 2:
        print("Usage: python imports.py <file_or_directory_path> [<file_or_directory_path> ...]")
        print("Options:")
        print("  --no-check-exists: Disable checking if imported modules exist")
        print("  --workspace-root=PATH: Specify the workspace root directory")
        sys.exit(1)
    
    files_with_violations = 0
    total_files_analyzed = 0
    check_file_exists = True
    workspace_root = None
    
    # Process command line arguments
    paths = []
    for arg in sys.argv[1:]:
        if arg == "--no-check-exists":
            check_file_exists = False
        elif arg.startswith("--workspace-root="):
            workspace_root = arg.split("=", 1)[1]
        else:
            paths.append(arg)
    
    if not paths:
        print("Error: No paths specified")
        sys.exit(1)
    
    # If workspace root wasn't specified, try to find it
    if workspace_root is None:
        workspace_root = find_workspace_root()
    
    print(f"Using workspace root: {workspace_root}")
    
    for path in paths:
        # Find all .star files if path is a directory
        files_to_analyze = find_star_files(path)
        
        for file_path in files_to_analyze:
            total_files_analyzed += 1
            violations = analyze_file(file_path, workspace_root, check_file_exists)
            
            if violations:
                files_with_violations += 1
                for line, message in violations:
                    print(f"{file_path}:{line}: {message}")
    
    print(f"\nAnalyzed {total_files_analyzed} .star files")
    
    if files_with_violations:
        print(f"Found violations in {files_with_violations} file(s)")
        sys.exit(1)
    else:
        print("No violations found")
        sys.exit(0)


if __name__ == "__main__":
    main()
