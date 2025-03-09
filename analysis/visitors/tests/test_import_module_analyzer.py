import unittest
import ast

from analysis.visitors.import_module_analyzer import ImportModuleAnalyzer
from analysis.visitors.import_module_analyzer import IMPORTS_STAR_FILENAME, IMPORTS_STAR_LOCATOR


class TestImportModuleAnalyzer(unittest.TestCase):
    """Test cases for the ImportModuleAnalyzer class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.analyzer = ImportModuleAnalyzer()
    
    def test_valid_import_module(self):
        """Test a valid import_module call."""
        code = """
_imports = import_module("/imports.star")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_invalid_import_module_path(self):
        """Test an import_module call with an invalid path."""
        code = """
_imports = import_module("/some/other/path.star")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the invalid path
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("only /imports.star can be imported", self.analyzer.violations[0][1])
    
    def test_invalid_import_module_args(self):
        """Test an import_module call with an invalid number of arguments."""
        code = """
_imports = import_module("/imports.star", "extra_arg")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the extra argument
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("has 2 arguments, expected exactly 1", self.analyzer.violations[0][1])
    
    def test_non_private_variable(self):
        """Test an import_module call assigned to a non-private variable."""
        code = """
imports = import_module("/imports.star")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the non-private variable
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("should be stored in private variables", self.analyzer.violations[0][1])
    
    def test_multiple_violations(self):
        """Test multiple violations in a single file."""
        code = """
imports = import_module("/some/other/path.star")
another = import_module("/imports.star", "extra_arg")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # Four violations should be reported:
        # 1. Non-private variable 'imports'
        # 2. Invalid path '/some/other/path.star'
        # 3. Non-private variable 'another'
        # 4. Extra argument in the second call
        self.assertEqual(len(self.analyzer.violations), 4)
    
    def test_imports_star_file(self):
        """Test that import_module calls in imports.star itself are allowed."""
        code = """
# This would normally be a violation, but it's allowed in imports.star
imports = import_module("/some/other/path.star")
another = import_module("/imports.star", "extra_arg")
"""
        node = ast.parse(code)
        
        # Set the file path to imports.star
        analyzer = ImportModuleAnalyzer(IMPORTS_STAR_FILENAME)
        analyzer.visit(node)
        
        # No violations should be reported because we're in imports.star
        self.assertEqual(len(analyzer.violations), 0)
    
    def test_visit_module_with_filename(self):
        """Test that the file path is correctly extracted from the module node."""
        code = """
_imports = import_module("/imports.star")
"""
        node = ast.parse(code)
        
        # Set the filename attribute on the node
        node.filename = "test_file.py"
        
        analyzer = ImportModuleAnalyzer()
        analyzer.visit(node)
        
        # Check that the file path was correctly extracted
        self.assertEqual(analyzer.file_path, "test_file.py")
        
        # No violations should be reported
        self.assertEqual(len(analyzer.violations), 0)
    
    def test_non_import_module_calls(self):
        """Test that other function calls are not analyzed."""
        code = """
result = some_other_function("/imports.star")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)


if __name__ == "__main__":
    unittest.main() 