"""
Call analyzer visitor for AST analysis.

This module contains the CallAnalyzer visitor that analyzes function calls in a file.
"""

import ast
from typing import Dict, Set, List, Tuple

from .base_visitor import BaseVisitor, debug_print
from .common import FunctionSignature, builtin_functions, builtin_modules, imports_valid_methods


class CallAnalyzer(BaseVisitor):
    """Analyzes function calls in a file."""
    
    def __init__(self, 
                 file_path: str,
                 local_functions: Dict[str, FunctionSignature],
                 imports: Dict[str, Dict],
                 all_functions: Dict[str, Dict[str, FunctionSignature]],
                 module_to_file: Dict[str, str],
                 imports_derived_vars: Dict[str, str] = None,
                 import_module_vars: Set[str] = None):
        super().__init__()
        self.file_path = file_path
        self.local_functions = local_functions
        self.imports = imports
        self.all_functions = all_functions
        self.module_to_file = module_to_file
        self.imports_derived_vars = imports_derived_vars or {}
        self.import_module_vars = import_module_vars or set()
    
    def visit_Call(self, node):
        """Visit function call nodes."""
        # Visit all arguments first to ensure any variables defined in them are in scope
        for arg in node.args:
            self.visit(arg)
        for kw in node.keywords:
            self.visit(kw.value)
        
        # Determine the function being called
        if isinstance(node.func, ast.Name):
            # Direct function call (e.g., my_function())
            func_name = node.func.id
            
            # Check if it's a local function
            if func_name in self.local_functions:
                target_signature = self.local_functions[func_name]
                self._check_call_compatibility(node, target_signature)
            # Check if it's a built-in function
            elif func_name in builtin_functions:
                # Built-in function, no need to check
                pass
            # Check if it's a variable in scope
            elif self._is_in_scope(func_name):
                # It's a variable in scope, but we can't trace it to a function
                # Skip the check as we can't determine if it's valid or not
                debug_print(f"Skipping check for function call through variable: {func_name}")
            else:
                # Not a local function, not a built-in, and not a variable in scope
                # This is definitely an error
                self.violations.append((
                    node.lineno,
                    f"Call to non-existing function or variable '{func_name}'"
                ))
        
        elif isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name):
            # Module attribute call (e.g., module.function())
            module_name = node.func.value.id
            func_name = node.func.attr
            
            # Check if this is a built-in module
            if module_name in builtin_modules:
                # Built-in module, no need to check
                debug_print(f"Skipping check for built-in module call: {module_name}.{func_name}")
                pass
            # Check if this is a call to an imported module
            elif module_name in self.imports:
                import_info = self.imports[module_name]
                
                # Only verify calls to local modules (no package_id)
                if import_info.package_id is None:
                    module_path = import_info.module_path
                    
                    # Debug logging
                    debug_print(f"Resolving call to {module_name}.{func_name} at line {node.lineno}")
                    debug_print(f"  Module path: {module_path}")
                    
                    # Try to find the target file
                    target_file = None
                    if module_path in self.module_to_file:
                        target_file = self.module_to_file[module_path]
                    else:
                        # Try with and without .star extension
                        if module_path.endswith('.star'):
                            module_path_no_ext = module_path[:-5]
                            if module_path_no_ext in self.module_to_file:
                                target_file = self.module_to_file[module_path_no_ext]
                        else:
                            module_path_with_ext = module_path + '.star'
                            if module_path_with_ext in self.module_to_file:
                                target_file = self.module_to_file[module_path_with_ext]
                    
                    if target_file and target_file in self.all_functions:
                        # Check if the function exists in the target file
                        target_functions = self.all_functions[target_file]
                        if func_name in target_functions:
                            target_signature = target_functions[func_name]
                            self._check_call_compatibility(node, target_signature)
                        else:
                            self.violations.append((
                                node.lineno,
                                f"Call to non-existing function '{module_name}.{func_name}'"
                            ))
                    else:
                        debug_print(f"  Could not find target file for module {module_path}")
            # Special case for _imports.load_module and _imports.ext
            elif module_name in self.import_module_vars and func_name in imports_valid_methods:
                # This is a valid call to _imports.load_module or _imports.ext
                debug_print(f"Valid call to {module_name}.{func_name}")
                
                # For load_module, check that it takes exactly one argument (the module path)
                if func_name == "load_module":
                    # Check argument count and types
                    if len(node.args) == 1:
                        # One positional argument is correct
                        pass
                    elif len(node.args) > 1:
                        # Too many positional arguments
                        self.violations.append((
                            node.lineno,
                            f"Call to {module_name}.{func_name} has too many positional arguments, only module_path is allowed"
                        ))
                    elif not any(kw.arg == "module_path" for kw in node.keywords):
                        # No module_path provided
                        self.violations.append((
                            node.lineno,
                            f"Call to {module_name}.{func_name} requires a module_path argument"
                        ))
                    
                    # Check for invalid keyword arguments
                    for kw in node.keywords:
                        if kw.arg and kw.arg != "module_path":
                            self.violations.append((
                                node.lineno,
                                f"Call to {module_name}.{func_name} has invalid keyword argument: {kw.arg}"
                            ))
            # Check if it's a variable derived from _imports (e.g., _imports.ext.ethereum_package)
            elif module_name in self.imports_derived_vars:
                # This is a variable derived from _imports, so it's valid
                debug_print(f"Valid call through variable derived from _imports: {module_name}.{func_name}")
                pass
            # Check if it's a variable in scope
            elif self._is_in_scope(module_name):
                # It's a variable in scope, but we can't trace what it refers to
                # Skip the check as we can't determine if it's valid or not
                debug_print(f"Skipping check for attribute call through variable: {module_name}.{func_name}")
            else:
                # Not an imported module and not a variable in scope
                # This is definitely an error
                self.violations.append((
                    node.lineno,
                    f"Call to non-existing module or variable '{module_name}'"
                ))
        else:
            # For other types of calls (e.g., complex expressions), visit the function expression
            self.visit(node.func)
    
    def _normalize_module_path(self, module_path: str) -> str:
        """Convert a module path to a file path."""
        # Remove leading slash if present
        if module_path.startswith('/'):
            module_path = module_path[1:]
        
        # If the path doesn't end with .star, add it
        if not module_path.endswith('.star'):
            module_path += '.star'
        
        # Just return the normalized path - we'll look it up in the module_to_file mapping
        return module_path
    
    def _check_call_compatibility(self, call_node: ast.Call, signature: FunctionSignature):
        """Check if a function call is compatible with the function signature."""
        # Count positional arguments
        pos_args_count = len(call_node.args)
        
        # Count required positional arguments in the signature
        required_args_count = len(signature.args) - len(signature.defaults)
        
        # Check if too few positional arguments
        if pos_args_count < required_args_count and not any(kw.arg in signature.args[:required_args_count] for kw in call_node.keywords):
            missing_args = set(signature.args[:required_args_count]) - {kw.arg for kw in call_node.keywords}
            debug_print(f"Call at line {call_node.lineno} is missing required arguments: {missing_args}")
            self.violations.append((
                call_node.lineno,
                f"Call to {signature.name} is missing required arguments: {', '.join(missing_args)}"
            ))
        
        # Check if too many positional arguments
        if not signature.vararg and pos_args_count > len(signature.args):
            debug_print(f"Call at line {call_node.lineno} has too many positional arguments")
            self.violations.append((
                call_node.lineno,
                f"Call to {signature.name} has too many positional arguments"
            ))
        
        # Check for unknown keyword arguments
        valid_kwargs = set(signature.args + signature.kwonlyargs)
        if not signature.kwarg:  # Only check if the function doesn't accept **kwargs
            for kw in call_node.keywords:
                if kw.arg and kw.arg not in valid_kwargs:
                    debug_print(f"Call at line {call_node.lineno} has unknown keyword argument: {kw.arg}")
                    self.violations.append((
                        call_node.lineno,
                        f"Call to {signature.name} has unknown keyword argument: {kw.arg}"
                    )) 