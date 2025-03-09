import unittest
import ast

from analysis.visitors.base_visitor import BaseVisitor

class TestBaseVisitor(unittest.TestCase):
    """Test cases for the BaseVisitor class."""

    def setUp(self):
        """Set up test fixtures."""
        self.visitor = BaseVisitor()
        # Reset verbosity to default for each test
        BaseVisitor.set_verbose(False)

    def test_set_verbose(self):
        """Test setting verbosity at class level."""
        # Default should be False
        self.assertFalse(BaseVisitor.verbose)
        
        # Set to True
        BaseVisitor.set_verbose(True)
        self.assertTrue(BaseVisitor.verbose)
        
        # Set back to False
        BaseVisitor.set_verbose(False)
        self.assertFalse(BaseVisitor.verbose)

    def test_debug_print(self):
        """Test debug print functionality."""
        import io
        from contextlib import redirect_stdout
        
        # Test with verbose=False (default)
        f = io.StringIO()
        with redirect_stdout(f):
            self.visitor.debug_print("Test message")
        self.assertEqual(f.getvalue(), "")
        
        # Test with verbose=True
        BaseVisitor.set_verbose(True)
        f = io.StringIO()
        with redirect_stdout(f):
            self.visitor.debug_print("Test message")
        self.assertEqual(f.getvalue(), "Test message\n")

    def test_scope_management(self):
        """Test scope management methods."""
        # Initial scope should be empty
        self.assertEqual(len(self.visitor.scopes), 1)
        self.assertEqual(self.visitor.scopes[0], set())
        
        # Test entering a new scope
        self.visitor._enter_scope()
        self.assertEqual(len(self.visitor.scopes), 2)
        
        # Test adding variables to current scope
        self.visitor._add_to_current_scope("var1")
        self.visitor._add_to_current_scope("var2")
        self.assertEqual(self.visitor.scopes[-1], {"var1", "var2"})
        
        # Test checking if variables are in scope
        self.assertTrue(self.visitor._is_in_scope("var1"))
        self.assertTrue(self.visitor._is_in_scope("var2"))
        self.assertFalse(self.visitor._is_in_scope("var3"))
        
        # Test exiting a scope
        self.visitor._exit_scope()
        self.assertEqual(len(self.visitor.scopes), 1)
        self.assertFalse(self.visitor._is_in_scope("var1"))
        self.assertFalse(self.visitor._is_in_scope("var2"))

    def test_visit_module(self):
        """Test visiting a module node."""
        code = """
x = 1
y = 2
"""
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # After visiting, we should have one scope left (the module scope)
        # The BaseVisitor doesn't automatically exit the module scope
        self.assertEqual(len(self.visitor.scopes), 1)

    def test_visit_function_def(self):
        """Test visiting a function definition."""
        code = """
def test_func(arg1, arg2, *args, kwarg1=None, **kwargs):
    x = 1
    y = 2
"""
        node = ast.parse(code)
        function_node = node.body[0]
        
        # Enter module scope first (as would happen in a real visit)
        self.visitor._enter_scope()
        
        # Visit the function
        self.visitor.visit_FunctionDef(function_node)
        
        # After visiting, we should be back to just the module scope
        # Plus the original scope we entered
        self.assertEqual(len(self.visitor.scopes), 2)

    def test_visit_class_def(self):
        """Test visiting a class definition."""
        code = """
class TestClass:
    class_var = 1
    
    def method(self):
        x = 1
"""
        node = ast.parse(code)
        class_node = node.body[0]
        
        # Enter module scope first (as would happen in a real visit)
        self.visitor._enter_scope()
        
        # Visit the class
        self.visitor.visit_ClassDef(class_node)
        
        # After visiting, we should be back to just the module scope
        # Plus the original scope we entered
        self.assertEqual(len(self.visitor.scopes), 2)

    def test_visit_for_loop(self):
        """Test visiting a for loop."""
        code = """
for i in range(10):
    x = i * 2
else:
    y = 0
"""
        node = ast.parse(code)
        for_node = node.body[0]
        
        # Enter module scope first (as would happen in a real visit)
        self.visitor._enter_scope()
        
        # Visit the for loop
        self.visitor.visit_For(for_node)
        
        # After visiting, we should be back to just the module scope
        # Plus the original scope we entered
        self.assertEqual(len(self.visitor.scopes), 2)

    def test_visit_while_loop(self):
        """Test visiting a while loop."""
        code = """
while True:
    x = 1
    break
else:
    y = 0
"""
        node = ast.parse(code)
        while_node = node.body[0]
        
        # Enter module scope first (as would happen in a real visit)
        self.visitor._enter_scope()
        
        # Visit the while loop
        self.visitor.visit_While(while_node)
        
        # After visiting, we should be back to just the module scope
        # Plus the original scope we entered
        self.assertEqual(len(self.visitor.scopes), 2)

    def test_visit_if_statement(self):
        """Test visiting an if statement."""
        code = """
if condition:
    x = 1
else:
    y = 2
"""
        node = ast.parse(code)
        if_node = node.body[0]
        
        # Enter module scope first (as would happen in a real visit)
        self.visitor._enter_scope()
        
        # Visit the if statement
        self.visitor.visit_If(if_node)
        
        # After visiting, we should be back to just the module scope
        # Plus the original scope we entered
        self.assertEqual(len(self.visitor.scopes), 2)

    def test_visit_with_statement(self):
        """Test visiting a with statement."""
        code = """
with open('file.txt') as f:
    content = f.read()
"""
        node = ast.parse(code)
        with_node = node.body[0]
        
        # Enter module scope first (as would happen in a real visit)
        self.visitor._enter_scope()
        
        # Visit the with statement
        self.visitor.visit_With(with_node)
        
        # After visiting, we should be back to just the module scope
        # Plus the original scope we entered
        self.assertEqual(len(self.visitor.scopes), 2)

    def test_visit_assign(self):
        """Test visiting an assignment statement."""
        code = """
x = 1
y, z = 2, 3
"""
        node = ast.parse(code)
        
        # Enter module scope first (as would happen in a real visit)
        self.visitor._enter_scope()
        
        # Visit the first assignment (simple)
        self.visitor.visit_Assign(node.body[0])
        self.assertTrue(self.visitor._is_in_scope("x"))
        
        # Visit the second assignment (tuple unpacking)
        self.visitor.visit_Assign(node.body[1])
        self.assertTrue(self.visitor._is_in_scope("y"))
        self.assertTrue(self.visitor._is_in_scope("z"))

    def test_complex_scope_tracking(self):
        """Test tracking variables across nested scopes."""
        code = """
global_var = 1

def outer_func(param1):
    outer_var = 2
    
    def inner_func(param2):
        inner_var = 3
        return param1 + param2 + inner_var + outer_var + global_var
    
    return inner_func

class TestClass:
    class_var = 4
    
    def method(self, param3):
        method_var = 5
        
        if True:
            if_var = 6
            for i in range(10):
                loop_var = i
"""
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # After visiting the entire module, we should have one scope left (the module scope)
        self.assertEqual(len(self.visitor.scopes), 1)

    def test_violations_tracking(self):
        """Test that violations are properly tracked."""
        # Initially, there should be no violations
        self.assertEqual(len(self.visitor.violations), 0)
        
        # Add a violation manually (this would normally be done by a subclass)
        self.visitor.violations.append((10, "Test violation message"))
        
        # Check that the violation was added
        self.assertEqual(len(self.visitor.violations), 1)
        self.assertEqual(self.visitor.violations[0], (10, "Test violation message"))

    def test_nested_scopes(self):
        """Test handling of deeply nested scopes."""
        # Create a series of nested scopes
        self.visitor._enter_scope()  # scope 1
        self.visitor._add_to_current_scope("var1")
        
        self.visitor._enter_scope()  # scope 2
        self.visitor._add_to_current_scope("var2")
        
        self.visitor._enter_scope()  # scope 3
        self.visitor._add_to_current_scope("var3")
        
        # Test that variables from all scopes are visible
        self.assertTrue(self.visitor._is_in_scope("var1"))
        self.assertTrue(self.visitor._is_in_scope("var2"))
        self.assertTrue(self.visitor._is_in_scope("var3"))
        
        # Exit scopes one by one and check visibility
        self.visitor._exit_scope()  # exit scope 3
        self.assertTrue(self.visitor._is_in_scope("var1"))
        self.assertTrue(self.visitor._is_in_scope("var2"))
        self.assertFalse(self.visitor._is_in_scope("var3"))
        
        self.visitor._exit_scope()  # exit scope 2
        self.assertTrue(self.visitor._is_in_scope("var1"))
        self.assertFalse(self.visitor._is_in_scope("var2"))
        
        self.visitor._exit_scope()  # exit scope 1
        self.assertFalse(self.visitor._is_in_scope("var1"))

    def test_empty_scopes_stack(self):
        """Test behavior when the scopes stack is empty."""
        # Empty the scopes stack
        while self.visitor.scopes:
            self.visitor._exit_scope()
        
        # Test adding to current scope when there is no scope
        self.visitor._add_to_current_scope("var1")
        
        # Should not raise an error, but also not add the variable
        self.assertFalse(self.visitor._is_in_scope("var1"))
        
        # Test exiting scope when there is no scope
        self.visitor._exit_scope()  # Should not raise an error


if __name__ == "__main__":
    unittest.main() 