"""
Base visitor module for AST analysis.

This module contains the base visitor class that other visitors can inherit from.
"""

import ast
from typing import List, Tuple, Set

class BaseVisitor(ast.NodeVisitor):
    """Base visitor class with common functionality."""
    
    # Class-level verbosity setting
    verbose = False
    
    @classmethod
    def set_verbose(cls, verbose: bool):
        """Set the verbosity for all BaseVisitor instances."""
        cls.verbose = verbose
    
    def __init__(self):
        self.violations: List[Tuple[int, str]] = []
        self.scopes: List[Set[str]] = [set()]  # Stack of variable scopes
    
    def debug_print(self, *args, **kwargs):
        """Print debug messages only when verbose mode is enabled."""
        if self.verbose:
            print(*args, **kwargs)
    
    def _enter_scope(self):
        """Enter a new variable scope."""
        self.scopes.append(set())
    
    def _exit_scope(self):
        """Exit the current variable scope."""
        if self.scopes:
            self.scopes.pop()
    
    def _add_to_current_scope(self, var_name: str):
        """Add a variable to the current scope."""
        if self.scopes:
            self.scopes[-1].add(var_name)
    
    def _is_in_scope(self, var_name: str) -> bool:
        """Check if a variable is in any scope."""
        return any(var_name in scope for scope in self.scopes)
    
    def visit_Module(self, node):
        """Visit the module node."""
        # Enter the module scope
        self._enter_scope()
        
        # Visit all statements in the module
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the module scope
        self._exit_scope()
    
    def visit_FunctionDef(self, node):
        """Visit function definition nodes."""
        # Enter a new scope for the function
        self._enter_scope()
        
        # Add function parameters to the scope
        for arg in node.args.args:
            self._add_to_current_scope(arg.arg)
        
        if node.args.vararg:
            self._add_to_current_scope(node.args.vararg.arg)
        
        for arg in node.args.kwonlyargs:
            self._add_to_current_scope(arg.arg)
        
        if node.args.kwarg:
            self._add_to_current_scope(node.args.kwarg.arg)
        
        # Visit the function body
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the function scope
        self._exit_scope()
    
    def visit_ClassDef(self, node):
        """Visit class definition nodes."""
        # Enter a new scope for the class
        self._enter_scope()
        
        # Visit the class body
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the class scope
        self._exit_scope()
    
    def visit_For(self, node):
        """Visit for loop nodes."""
        # Visit the iterable expression
        self.visit(node.iter)
        
        # Enter a new scope for the loop
        self._enter_scope()
        
        # Add loop variables to the scope
        if isinstance(node.target, ast.Name):
            self._add_to_current_scope(node.target.id)
        elif isinstance(node.target, ast.Tuple):
            for elt in node.target.elts:
                if isinstance(elt, ast.Name):
                    self._add_to_current_scope(elt.id)
        
        # Visit the loop body
        for stmt in node.body:
            self.visit(stmt)
        
        # Visit the else clause if present
        if node.orelse:
            for stmt in node.orelse:
                self.visit(stmt)
        
        # Exit the loop scope
        self._exit_scope()
    
    def visit_While(self, node):
        """Visit while loop nodes."""
        # Visit the condition expression
        self.visit(node.test)
        
        # Enter a new scope for the loop
        self._enter_scope()
        
        # Visit the loop body
        for stmt in node.body:
            self.visit(stmt)
        
        # Visit the else clause if present
        if node.orelse:
            for stmt in node.orelse:
                self.visit(stmt)
        
        # Exit the loop scope
        self._exit_scope()
    
    def visit_If(self, node):
        """Visit if statement nodes."""
        # Visit the condition expression
        self.visit(node.test)
        
        # Enter a new scope for the if branch
        self._enter_scope()
        
        # Visit the if body
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the if scope
        self._exit_scope()
        
        # Enter a new scope for the else branch
        self._enter_scope()
        
        # Visit the else clause if present
        if node.orelse:
            for stmt in node.orelse:
                self.visit(stmt)
        
        # Exit the else scope
        self._exit_scope()
    
    def visit_With(self, node):
        """Visit with statement nodes."""
        # Visit the context expressions
        for item in node.items:
            self.visit(item.context_expr)
            if item.optional_vars:
                # If there's an as clause, visit it
                if isinstance(item.optional_vars, ast.Name):
                    self._add_to_current_scope(item.optional_vars.id)
                elif isinstance(item.optional_vars, ast.Tuple):
                    for elt in item.optional_vars.elts:
                        if isinstance(elt, ast.Name):
                            self._add_to_current_scope(elt.id)
        
        # Enter a new scope for the with block
        self._enter_scope()
        
        # Visit the with body
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the with scope
        self._exit_scope()
    
    def visit_Assign(self, node):
        """Visit an assignment statement."""
        # Process the value expression first
        self.visit(node.value)
        
        # Add assigned variables to the current scope
        for target in node.targets:
            if isinstance(target, ast.Name):
                self._add_to_current_scope(target.id)
            elif isinstance(target, ast.Tuple):
                for elt in target.elts:
                    if isinstance(elt, ast.Name):
                        self._add_to_current_scope(elt.id) 