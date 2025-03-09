"""
Load module analyzer visitor for AST analysis.

This module contains the LoadModuleAnalyzer visitor that tracks import_module assignments and verifies that
load_module calls without package_id have valid relative paths.
"""

import ast
import os
import glob
from typing import List, Tuple, Set

from .base_visitor import BaseVisitor

# Constants
IMPORTS_STAR_FILENAME = "imports.star"
IMPORT_MODULE_FUNC = "import_module"
LOAD_MODULE_FUNC = "load_module"
MODULE_PATH_ARG = "module_path"
PACKAGE_ID_ARG = "package_id"
STAR_FILE_EXTENSION = ".star"
IMPORTS_STAR_LOCATOR = "/{0}".format(IMPORTS_STAR_FILENAME)


class LoadModuleAnalyzer(BaseVisitor):
    """
    AST visitor that tracks import_module assignments and verifies that
    load_module calls without package_id have valid relative paths.
    """
    
    def __init__(self, file_path: str, workspace_root: str = None, check_file_exists: bool = True):
        super().__init__()
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
        super().visit_Assign(node)
    
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
                        if isinstance(module_path_node, ast.Constant) and isinstance(module_path_node.value, str):
                            module_path = module_path_node.value
                    # Or from keyword argument
                    else:
                        for kw in node.keywords:
                            if kw.arg == MODULE_PATH_ARG and isinstance(kw.value, ast.Constant) and isinstance(kw.value.value, str):
                                module_path = kw.value.value
                    
                    # If we have a module_path, check if it's valid
                    if module_path:
                        # Check if it's a valid relative path
                        if not self._is_valid_relative_path(module_path):
                            self.violations.append((
                                node.lineno,
                                f"Invalid module path: {module_path}. Module paths should be relative to the workspace root."
                            ))
                        # Check if the module exists
                        elif self.check_file_exists and not self._module_exists(module_path):
                            self.violations.append((
                                node.lineno,
                                f"load_module references non-existent module: '{module_path}'"
                            ))
        
        # Continue visiting child nodes
        self.generic_visit(node)
    
    def _is_valid_relative_path(self, path: str) -> bool:
        """Check if a path is a valid relative path."""
        # Path should not start with a slash (except for /imports.star)
        if path.startswith('/') and path != IMPORTS_STAR_LOCATOR:
            # Check if it's a valid absolute path within the workspace
            abs_path = os.path.normpath(os.path.join(self.workspace_root, path[1:]))
            return abs_path.startswith(self.workspace_root)
        
        # Path should not contain .. (parent directory references)
        if '..' in path.split('/'):
            return False
        
        # Path should not be absolute
        if os.path.isabs(path):
            return False
        
        return True
    
    def _module_exists(self, module_path: str) -> bool:
        """Check if a module exists in the workspace."""
        # Handle special case for /imports.star
        if module_path == IMPORTS_STAR_LOCATOR:
            return True
        
        # Normalize the path
        if module_path.startswith('/'):
            module_path = module_path[1:]
        
        # Try with and without .star extension
        paths_to_check = [module_path]
        if not module_path.endswith(STAR_FILE_EXTENSION):
            paths_to_check.append(module_path + STAR_FILE_EXTENSION)
        
        # Check if any of the paths exist
        for path in paths_to_check:
            full_path = os.path.join(self.workspace_root, path)
            if os.path.isfile(full_path):
                return True
        
        # If we get here, the module doesn't exist
        return False 