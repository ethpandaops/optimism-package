"""
Import collector visitor for AST analysis.

This module contains the ImportCollector visitor that collects import information from a file.
"""

import ast
from typing import Dict, Set

from .common import ImportInfo
from .base_visitor import BaseVisitor


class ImportCollector(BaseVisitor):
    """Collects import information from a file."""
    
    def __init__(self):
        super().__init__()
        self.imports: Dict[str, ImportInfo] = {}  # Variable name -> ImportInfo
        self.import_module_vars: Set[str] = set()  # Variables assigned from import_module("/imports.star")
        self.imports_derived_vars: Dict[str, str] = {}  # Variables derived from _imports (e.g., _imports.ext)
    
    def visit_Assign(self, node):
        """Visit assignment nodes to track imports."""
        # Check if this is an assignment from import_module
        if (isinstance(node.value, ast.Call) and 
            isinstance(node.value.func, ast.Name) and 
            node.value.func.id == 'import_module'):
            
            # Check if it's importing "/imports.star"
            if (len(node.value.args) == 1 and 
                isinstance(node.value.args[0], ast.Constant) and 
                isinstance(node.value.args[0].value, str) and 
                node.value.args[0].value == "/imports.star"):
                
                # Add all target variables to our tracked set
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        self.import_module_vars.add(target.id)
        
        # Check if this is an assignment from VARIABLE.load_module
        elif (isinstance(node.value, ast.Call) and 
              isinstance(node.value.func, ast.Attribute) and 
              node.value.func.attr == 'load_module' and
              isinstance(node.value.func.value, ast.Name) and
              node.value.func.value.id in self.import_module_vars):
            
            # Extract module_path and package_id
            module_path = None
            package_id = None
            
            # Get module_path from positional or keyword arguments
            if len(node.value.args) >= 1:
                arg = node.value.args[0]
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                    module_path = arg.value
            
            for kw in node.value.keywords:
                if kw.arg == 'module_path' and isinstance(kw.value, ast.Constant) and isinstance(kw.value.value, str):
                    module_path = kw.value.value
                elif kw.arg == 'package_id' and isinstance(kw.value, ast.Constant):
                    if isinstance(kw.value.value, str) or kw.value.value is None:
                        package_id = kw.value.value
            
            # Get package_id from second positional argument if present
            if len(node.value.args) >= 2 and package_id is None:
                arg = node.value.args[1]
                if isinstance(arg, ast.Constant):
                    if isinstance(arg.value, str) or arg.value is None:
                        package_id = arg.value
            
            # If we have a valid module_path, record the import
            if module_path:
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        # For now, assume all names from the module are imported
                        # This is a simplification; in a real implementation, we'd need to analyze
                        # the imported module to get the actual exported names
                        self.imports[target.id] = ImportInfo(
                            module_path=module_path,
                            package_id=package_id,
                            imported_names={}  # Will be populated later if needed
                        )
        
        # Track variables derived from _imports (e.g., _imports.ext.ethereum_package)
        elif isinstance(node.value, ast.Attribute) and isinstance(node.value.value, ast.Name):
            base_var = node.value.value.id
            if base_var in self.import_module_vars or base_var in self.imports_derived_vars:
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        self.imports_derived_vars[target.id] = base_var
        
        # Also track multi-level attribute access (e.g., _imports.ext.ethereum_package)
        elif (isinstance(node.value, ast.Attribute) and 
              isinstance(node.value.value, ast.Attribute) and 
              isinstance(node.value.value.value, ast.Name)):
            base_var = node.value.value.value.id
            if base_var in self.import_module_vars:
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        self.imports_derived_vars[target.id] = base_var
        
        # Continue visiting child nodes
        super().visit_Assign(node)
    
    def visit_ImportFrom(self, node):
        """Visit import from statements."""
        # Standard Python imports are not our focus, but we'll track them for completeness
        if node.module:
            imported_names = {}
            for name in node.names:
                imported_names[name.asname or name.name] = name.name
            
            # We don't have package_id for standard imports
            self.imports[node.module] = ImportInfo(
                module_path=node.module,
                package_id=None,
                imported_names=imported_names
            )
        
        # Continue visiting child nodes
        self.generic_visit(node) 