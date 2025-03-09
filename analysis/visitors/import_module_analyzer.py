"""
Import module analyzer visitor for AST analysis.

This module contains the ImportModuleAnalyzer visitor that finds calls to import_module and checks their arguments.
"""

import ast
import os
from typing import List, Tuple

from .base_visitor import BaseVisitor, debug_print

# Constants
IMPORTS_STAR_FILENAME = "imports.star"
IMPORT_MODULE_FUNC = "import_module"
LOAD_MODULE_FUNC = "load_module"
IMPORTS_STAR_LOCATOR = "/{0}".format(IMPORTS_STAR_FILENAME)


class ImportModuleAnalyzer(BaseVisitor):
    """AST visitor that finds calls to import_module and checks their arguments."""
    
    def __init__(self, file_path=""):
        super().__init__()
        self.file_path = file_path
    
    def visit_Module(self, node):
        """Visit the module node and check the current file name."""
        # Get the current file name from the node's filename attribute
        if hasattr(node, 'filename'):
            self.file_path = node.filename
        
        # Continue with normal visit
        super().visit_Module(node)
    
    def visit_Call(self, node):
        """Visit a function call node in the AST."""
        # Check if this is a call to import_module
        if isinstance(node.func, ast.Name) and node.func.id == IMPORT_MODULE_FUNC:
            # Skip validation if we're in imports.star itself
            if self.file_path and os.path.basename(self.file_path) == IMPORTS_STAR_FILENAME:
                debug_print(f"Allowing import_module in {IMPORTS_STAR_FILENAME} itself")
                self.generic_visit(node)
                return
            
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
            
            # Skip validation if we're in imports.star itself
            if self.file_path and os.path.basename(self.file_path) == IMPORTS_STAR_FILENAME:
                debug_print(f"Allowing import_module assignment in {IMPORTS_STAR_FILENAME} itself")
                super().visit_Assign(node)
                return
            
            # Check that all target variables start with underscore
            for target in node.targets:
                if isinstance(target, ast.Name) and not target.id.startswith('_'):
                    self.violations.append((
                        node.lineno,
                        f"Results of {IMPORT_MODULE_FUNC} should be stored in private variables (starting with '_') to keep imports scoped to the current file"
                    ))
        
        # Continue visiting child nodes
        super().visit_Assign(node) 