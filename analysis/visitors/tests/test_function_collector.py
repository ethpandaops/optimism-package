import unittest
import ast

from analysis.visitors.function_collector import FunctionCollector
from analysis.visitors.common import FunctionSignature


class TestFunctionCollector(unittest.TestCase):
    """Test cases for the FunctionCollector class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.test_file_path = "test_file.py"
        self.collector = FunctionCollector(self.test_file_path)
    
    def test_simple_function(self):
        """Test collecting a simple function with no parameters."""
        code = """
def simple_function():
    return "Hello, World!"
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that the function was collected
        self.assertIn("simple_function", self.collector.functions)
        
        # Check the function signature
        func = self.collector.functions["simple_function"]
        self.assertEqual(func.name, "simple_function")
        self.assertEqual(func.file_path, self.test_file_path)
        self.assertEqual(func.lineno, 2)  # Line number in the parsed code
        self.assertEqual(func.args, [])
        self.assertEqual(func.defaults, [])
        self.assertEqual(func.kwonlyargs, [])
        self.assertEqual(func.kwdefaults, {})
        self.assertIsNone(func.vararg)
        self.assertIsNone(func.kwarg)
    
    def test_function_with_args(self):
        """Test collecting a function with positional arguments."""
        code = """
def greet(name, greeting="Hello"):
    return f"{greeting}, {name}!"
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that the function was collected
        self.assertIn("greet", self.collector.functions)
        
        # Check the function signature
        func = self.collector.functions["greet"]
        self.assertEqual(func.name, "greet")
        self.assertEqual(func.file_path, self.test_file_path)
        self.assertEqual(func.lineno, 2)
        self.assertEqual(func.args, ["name", "greeting"])
        self.assertEqual(func.defaults, ["Hello"])
        self.assertEqual(func.kwonlyargs, [])
        self.assertEqual(func.kwdefaults, {})
        self.assertIsNone(func.vararg)
        self.assertIsNone(func.kwarg)
    
    def test_function_with_complex_args(self):
        """Test collecting a function with various parameter types."""
        code = """
def complex_func(a, b, c=1, d=2, *args, e=3, f=4, **kwargs):
    return a + b + c + d + sum(args) + e + f + sum(kwargs.values())
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that the function was collected
        self.assertIn("complex_func", self.collector.functions)
        
        # Check the function signature
        func = self.collector.functions["complex_func"]
        self.assertEqual(func.name, "complex_func")
        self.assertEqual(func.file_path, self.test_file_path)
        self.assertEqual(func.lineno, 2)
        self.assertEqual(func.args, ["a", "b", "c", "d"])
        self.assertEqual(func.defaults, [1, 2])
        self.assertEqual(func.kwonlyargs, ["e", "f"])
        self.assertEqual(func.kwdefaults, {"e": 3, "f": 4})
        self.assertEqual(func.vararg, "args")
        self.assertEqual(func.kwarg, "kwargs")
    
    def test_nested_functions(self):
        """Test collecting nested functions."""
        code = """
def outer(x):
    def inner(y):
        return x + y
    return inner
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that both functions were collected
        self.assertIn("outer", self.collector.functions)
        self.assertIn("inner", self.collector.functions)
        
        # Check the outer function signature
        outer_func = self.collector.functions["outer"]
        self.assertEqual(outer_func.name, "outer")
        self.assertEqual(outer_func.args, ["x"])
        
        # Check the inner function signature
        inner_func = self.collector.functions["inner"]
        self.assertEqual(inner_func.name, "inner")
        self.assertEqual(inner_func.args, ["y"])
    
    def test_class_methods(self):
        """Test collecting methods from a class."""
        code = """
class TestClass:
    def __init__(self, value):
        self.value = value
    
    def get_value(self):
        return self.value
    
    @classmethod
    def from_string(cls, string):
        return cls(int(string))
    
    @staticmethod
    def utility():
        return "utility"
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that all methods were collected
        self.assertIn("__init__", self.collector.functions)
        self.assertIn("get_value", self.collector.functions)
        self.assertIn("from_string", self.collector.functions)
        self.assertIn("utility", self.collector.functions)
        
        # Check the __init__ method signature
        init_method = self.collector.functions["__init__"]
        self.assertEqual(init_method.name, "__init__")
        self.assertEqual(init_method.args, ["self", "value"])
        
        # Check the get_value method signature
        get_value_method = self.collector.functions["get_value"]
        self.assertEqual(get_value_method.name, "get_value")
        self.assertEqual(get_value_method.args, ["self"])
        
        # Check the from_string class method signature
        from_string_method = self.collector.functions["from_string"]
        self.assertEqual(from_string_method.name, "from_string")
        self.assertEqual(from_string_method.args, ["cls", "string"])
        
        # Check the utility static method signature
        utility_method = self.collector.functions["utility"]
        self.assertEqual(utility_method.name, "utility")
        self.assertEqual(utility_method.args, [])
    
    def test_non_constant_defaults(self):
        """Test handling of non-constant default values."""
        code = """
def func_with_non_constant_defaults(a, b=[], c=some_variable):
    return a + b + [c]
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that the function was collected
        self.assertIn("func_with_non_constant_defaults", self.collector.functions)
        
        # Check the function signature
        func = self.collector.functions["func_with_non_constant_defaults"]
        self.assertEqual(func.name, "func_with_non_constant_defaults")
        self.assertEqual(func.args, ["a", "b", "c"])
        
        # Non-constant defaults should be None
        self.assertEqual(func.defaults, [None, None])
    
    def test_multiple_functions(self):
        """Test collecting multiple functions from a single file."""
        code = """
def func1():
    pass

def func2(a, b):
    pass

def func3(x, y=1, z=2):
    pass
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that all functions were collected
        self.assertIn("func1", self.collector.functions)
        self.assertIn("func2", self.collector.functions)
        self.assertIn("func3", self.collector.functions)
        
        # Check function counts
        self.assertEqual(len(self.collector.functions), 3)


if __name__ == "__main__":
    unittest.main() 