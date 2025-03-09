"""
Function collector visitor for AST analysis.

This module contains the FunctionCollector visitor that collects function definitions from a file.
"""

import ast
from typing import Dict

from .common import FunctionSignature
from .base_visitor import BaseVisitor


class FunctionCollector(BaseVisitor):
    """Collects function definitions from a file."""
    
    def __init__(self, file_path: str):
        super().__init__()
        self.file_path = file_path
        self.functions: Dict[str, FunctionSignature] = {}
    
    def visit_FunctionDef(self, node):
        """Visit function definition nodes."""
        # Extract function name
        func_name = node.name
        
        # Extract positional arguments
        args = []
        for arg in node.args.args:
            args.append(arg.arg)
        
        # Extract default values for optional arguments
        defaults = []
        for default in node.args.defaults:
            if isinstance(default, ast.Constant):
                defaults.append(default.value)
            else:
                # For non-constant defaults, use None as a placeholder
                defaults.append(None)
        
        # Extract *args parameter
        vararg = node.args.vararg.arg if node.args.vararg else None
        
        # Extract keyword-only arguments
        kwonlyargs = []
        for arg in node.args.kwonlyargs:
            kwonlyargs.append(arg.arg)
        
        # Extract default values for keyword-only arguments
        kwdefaults = {}
        for i, arg in enumerate(node.args.kwonlyargs):
            default = node.args.kw_defaults[i]
            if default and isinstance(default, ast.Constant):
                kwdefaults[arg.arg] = default.value
            else:
                kwdefaults[arg.arg] = None
        
        # Extract **kwargs parameter
        kwarg = node.args.kwarg.arg if node.args.kwarg else None
        
        # Create function signature
        signature = FunctionSignature(
            name=func_name,
            file_path=self.file_path,
            lineno=node.lineno,
            args=args,
            defaults=defaults,
            kwonlyargs=kwonlyargs,
            kwdefaults=kwdefaults,
            vararg=vararg,
            kwarg=kwarg
        )
        
        # Add to functions dictionary
        self.functions[func_name] = signature
        
        # Continue visiting child nodes
        super().visit_FunctionDef(node) 