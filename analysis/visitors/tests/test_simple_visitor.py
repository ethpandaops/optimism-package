import unittest
import ast

from analysis.visitors.base_visitor import BaseVisitor

class SimpleVisitor(BaseVisitor):
    """A simple visitor that collects variable names."""
    
    def __init__(self):
        super().__init__()
        self.variable_names = set()
    
    def visit_Assign(self, node):
        """Visit an assignment statement."""
        # Visit the value first
        self.visit(node.value)
        
        # Process the targets (left side of assignment)
        for target in node.targets:
            if isinstance(target, ast.Name):
                self.variable_names.add(target.id)
                self._add_to_current_scope(target.id)
            elif isinstance(target, ast.Tuple):
                for elt in target.elts:
                    if isinstance(elt, ast.Name):
                        self.variable_names.add(elt.id)
                        self._add_to_current_scope(elt.id)
    
    def visit_Name(self, node):
        """Visit a name node."""
        if isinstance(node.ctx, ast.Load):
            # This is a variable being used
            if not self._is_in_scope(node.id):
                # Report a violation if the variable is not in scope
                self.violations.append((node.lineno, f"Variable '{node.id}' used before definition"))
    
    def visit_FunctionDef(self, node):
        """Visit function definition nodes."""
        # Add the function name to the current scope
        self.variable_names.add(node.name)
        self._add_to_current_scope(node.name)
        
        # Enter a new scope for the function
        self._enter_scope()
        
        # Add function parameters to the scope
        for arg in node.args.args:
            self.variable_names.add(arg.arg)
            self._add_to_current_scope(arg.arg)
        
        if node.args.vararg:
            self.variable_names.add(node.args.vararg.arg)
            self._add_to_current_scope(node.args.vararg.arg)
        
        for arg in node.args.kwonlyargs:
            self.variable_names.add(arg.arg)
            self._add_to_current_scope(arg.arg)
        
        if node.args.kwarg:
            self.variable_names.add(node.args.kwarg.arg)
            self._add_to_current_scope(node.args.kwarg.arg)
        
        # Visit the function body
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the function scope
        self._exit_scope()


class TestSimpleVisitor(unittest.TestCase):
    """Test cases for the SimpleVisitor class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.visitor = SimpleVisitor()
    
    def test_variable_collection(self):
        """Test that variables are correctly collected."""
        code = """
x = 1
y = 2
z = x + y
"""
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # Check that all variables were collected
        self.assertEqual(self.visitor.variable_names, {"x", "y", "z"})
        
        # Check that no violations were reported
        self.assertEqual(len(self.visitor.violations), 0)
    
    def test_undefined_variable(self):
        """Test that using an undefined variable is reported as a violation."""
        code = """
x = y  # y is not defined
"""
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # Check that x was collected
        self.assertEqual(self.visitor.variable_names, {"x"})
        
        # Check that a violation was reported for y
        self.assertEqual(len(self.visitor.violations), 1)
        self.assertEqual(self.visitor.violations[0][1], "Variable 'y' used before definition")
    
    def test_function_scope(self):
        """Test that function scopes are correctly handled."""
        code = """
x = 1

def func(param):
    y = x + param  # x is in outer scope, param is in current scope
    return y
"""
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # Check that all variables were collected
        self.assertEqual(self.visitor.variable_names, {"x", "func", "param", "y"})
        
        # Check that no violations were reported
        self.assertEqual(len(self.visitor.violations), 0)
    
    def test_nested_functions(self):
        """Test that nested function scopes are correctly handled."""
        code = """
x = 1

def outer(param1):
    y = x + param1
    
    def inner(param2):
        z = y + param2
        return z
    
    return inner
"""
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # Check that all variables were collected
        self.assertEqual(self.visitor.variable_names, {"x", "outer", "param1", "y", "inner", "param2", "z"})
        
        # Check that no violations were reported
        self.assertEqual(len(self.visitor.violations), 0)
    
    def test_scope_violations(self):
        """Test that scope violations are correctly reported."""
        code = """
def func():
    x = y  # y is not defined
    
    def inner():
        z = a  # a is not defined
"""
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # Check that variables were collected
        self.assertEqual(self.visitor.variable_names, {"func", "x", "inner", "z"})
        
        # Check that violations were reported for y and a
        self.assertEqual(len(self.visitor.violations), 2)
        violation_messages = [v[1] for v in self.visitor.violations]
        self.assertIn("Variable 'y' used before definition", violation_messages)
        self.assertIn("Variable 'a' used before definition", violation_messages)


if __name__ == "__main__":
    unittest.main() 