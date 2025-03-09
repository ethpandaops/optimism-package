import unittest
import ast
import os
import tempfile

from analysis.visitors.call_analyzer import CallAnalyzer
from analysis.visitors.common import FunctionSignature, ImportInfo


class TestCallAnalyzer(unittest.TestCase):
    """Test cases for the CallAnalyzer class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.test_file_path = os.path.join(self.temp_dir, "test_file.star")
        
        # Create sample function signatures
        self.local_functions = {
            "local_func": FunctionSignature(
                name="local_func",
                file_path=self.test_file_path,
                lineno=1,
                args=["arg1", "arg2"],
                defaults=[],
                kwonlyargs=[],
                kwdefaults={},
                vararg=None,
                kwarg=None
            ),
            "local_func_with_defaults": FunctionSignature(
                name="local_func_with_defaults",
                file_path=self.test_file_path,
                lineno=5,
                args=["arg1", "arg2", "arg3"],
                defaults=["default2", "default3"],
                kwonlyargs=[],
                kwdefaults={},
                vararg=None,
                kwarg=None
            ),
            "local_func_with_varargs": FunctionSignature(
                name="local_func_with_varargs",
                file_path=self.test_file_path,
                lineno=10,
                args=["arg1"],
                defaults=[],
                kwonlyargs=[],
                kwdefaults={},
                vararg="args",
                kwarg=None
            ),
            "local_func_with_kwargs": FunctionSignature(
                name="local_func_with_kwargs",
                file_path=self.test_file_path,
                lineno=15,
                args=["arg1"],
                defaults=[],
                kwonlyargs=[],
                kwdefaults={},
                vararg=None,
                kwarg="kwargs"
            )
        }
        
        # Create sample imports
        self.imports = {
            "module1": ImportInfo(
                module_path="module1",
                package_id=None,
                imported_names={}
            ),
            "module2": ImportInfo(
                module_path="module2",
                package_id="package-id",
                imported_names={}
            )
        }
        
        # Create sample module functions
        module1_functions = {
            "module1_func": FunctionSignature(
                name="module1_func",
                file_path=os.path.join(self.temp_dir, "module1.star"),
                lineno=1,
                args=["arg1", "arg2"],
                defaults=[],
                kwonlyargs=[],
                kwdefaults={},
                vararg=None,
                kwarg=None
            )
        }
        
        # Create all_functions dictionary
        self.all_functions = {
            os.path.join(self.temp_dir, "module1.star"): module1_functions
        }
        
        # Create module_to_file mapping
        self.module_to_file = {
            "module1": os.path.join(self.temp_dir, "module1.star")
        }
        
        # Create imports_derived_vars and import_module_vars
        self.imports_derived_vars = {
            "ext": "_imports"
        }
        self.import_module_vars = {"_imports"}
        
        # Create test files
        self.create_test_files()
        
        # Create the analyzer
        self.analyzer = CallAnalyzer(
            file_path=self.test_file_path,
            local_functions=self.local_functions,
            imports=self.imports,
            all_functions=self.all_functions,
            module_to_file=self.module_to_file,
            imports_derived_vars=self.imports_derived_vars,
            import_module_vars=self.import_module_vars
        )
    
    def create_test_files(self):
        """Create test files in the temporary workspace."""
        # Create module1.star
        with open(os.path.join(self.temp_dir, "module1.star"), "w") as f:
            f.write("""
def module1_func(arg1, arg2):
    return arg1 + arg2
""")
    
    def tearDown(self):
        """Clean up test fixtures."""
        # Remove the temporary directory and its contents
        for root, dirs, files in os.walk(self.temp_dir, topdown=False):
            for name in files:
                os.remove(os.path.join(root, name))
            for name in dirs:
                os.rmdir(os.path.join(root, name))
        os.rmdir(self.temp_dir)
    
    def test_local_function_call_valid(self):
        """Test a valid call to a local function."""
        code = """
result = local_func("value1", "value2")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_local_function_call_missing_args(self):
        """Test a call to a local function with missing arguments."""
        code = """
result = local_func("value1")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the missing argument
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("missing required arguments", self.analyzer.violations[0][1])
    
    def test_local_function_call_too_many_args(self):
        """Test a call to a local function with too many arguments."""
        code = """
result = local_func("value1", "value2", "value3")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for too many arguments
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("too many positional arguments", self.analyzer.violations[0][1])
    
    def test_local_function_call_with_defaults(self):
        """Test a call to a local function with default arguments."""
        code = """
result = local_func_with_defaults("value1")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_local_function_call_with_keyword_args(self):
        """Test a call to a local function with keyword arguments."""
        code = """
result = local_func(arg2="value2", arg1="value1")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_local_function_call_with_unknown_keyword(self):
        """Test a call to a local function with an unknown keyword argument."""
        code = """
result = local_func("value1", "value2", unknown="value")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the unknown keyword
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("unknown keyword argument", self.analyzer.violations[0][1])
    
    def test_local_function_call_with_varargs(self):
        """Test a call to a local function with variable arguments."""
        code = """
result = local_func_with_varargs("value1", "value2", "value3")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_local_function_call_with_kwargs(self):
        """Test a call to a local function with keyword arguments."""
        code = """
result = local_func_with_kwargs("value1", unknown1="value", unknown2="value")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_non_existent_function_call(self):
        """Test a call to a non-existent function."""
        code = """
result = non_existent_func("value1", "value2")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the non-existent function
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("non-existing function", self.analyzer.violations[0][1])
    
    def test_module_function_call_valid(self):
        """Test a valid call to a module function."""
        code = """
result = module1.module1_func("value1", "value2")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_module_function_call_missing_args(self):
        """Test a call to a module function with missing arguments."""
        code = """
result = module1.module1_func("value1")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the missing argument
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("missing required arguments", self.analyzer.violations[0][1])
    
    def test_non_existent_module_function_call(self):
        """Test a call to a non-existent module function."""
        code = """
result = module1.non_existent_func("value1", "value2")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the non-existent function
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("non-existing function", self.analyzer.violations[0][1])
    
    def test_non_existent_module_call(self):
        """Test a call to a non-existent module."""
        code = """
result = non_existent_module.func("value1", "value2")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the non-existent module
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("non-existing module", self.analyzer.violations[0][1])
    
    def test_imports_load_module_call_valid(self):
        """Test a valid call to _imports.load_module."""
        code = """
result = _imports.load_module("module_path")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_imports_load_module_call_too_many_args(self):
        """Test a call to _imports.load_module with too many arguments."""
        code = """
result = _imports.load_module("module_path", "extra_arg")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for too many arguments
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("too many positional arguments", self.analyzer.violations[0][1])
    
    def test_imports_load_module_call_invalid_keyword(self):
        """Test a call to _imports.load_module with an invalid keyword argument."""
        code = """
result = _imports.load_module(module_path="path", invalid_arg="value")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the invalid keyword
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("invalid keyword argument", self.analyzer.violations[0][1])
    
    def test_imports_derived_var_call(self):
        """Test a call through a variable derived from _imports."""
        code = """
result = ext.some_function("value1", "value2")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)


if __name__ == "__main__":
    unittest.main() 