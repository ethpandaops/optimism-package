import unittest
import ast
import os
import tempfile

from analysis.visitors.load_module_analyzer import LoadModuleAnalyzer
from analysis.visitors.load_module_analyzer import IMPORTS_STAR_FILENAME, IMPORTS_STAR_LOCATOR


class TestLoadModuleAnalyzer(unittest.TestCase):
    """Test cases for the LoadModuleAnalyzer class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.test_file_path = os.path.join(self.temp_dir, "test_file.star")
        
        # Create a temporary workspace with some test files
        self.create_test_files()
        
        # Create an analyzer with check_file_exists=False for most tests
        self.analyzer = LoadModuleAnalyzer(
            file_path=self.test_file_path,
            workspace_root=self.temp_dir,
            check_file_exists=False
        )
    
    def create_test_files(self):
        """Create test files in the temporary workspace."""
        # Create imports.star
        with open(os.path.join(self.temp_dir, IMPORTS_STAR_FILENAME), "w") as f:
            f.write("# Test imports.star file")
        
        # Create a test module
        with open(os.path.join(self.temp_dir, "test_module.star"), "w") as f:
            f.write("# Test module file")
        
        # Create a subdirectory with a module
        os.makedirs(os.path.join(self.temp_dir, "subdir"), exist_ok=True)
        with open(os.path.join(self.temp_dir, "subdir", "sub_module.star"), "w") as f:
            f.write("# Test submodule file")
    
    def tearDown(self):
        """Clean up test fixtures."""
        # Remove the temporary directory and its contents
        for root, dirs, files in os.walk(self.temp_dir, topdown=False):
            for name in files:
                os.remove(os.path.join(root, name))
            for name in dirs:
                os.rmdir(os.path.join(root, name))
        os.rmdir(self.temp_dir)
    
    def test_import_module_tracking(self):
        """Test tracking variables assigned from import_module('/imports.star')."""
        code = """
_imports = import_module("/imports.star")
other_var = import_module("/some/other/path.star")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # Check that '_imports' is tracked
        self.assertIn("_imports", self.analyzer.import_vars)
        
        # Check that 'other_var' is not tracked (wrong path)
        self.assertNotIn("other_var", self.analyzer.import_vars)
    
    def test_load_module_non_private_variable(self):
        """Test that load_module results should be stored in private variables."""
        code = """
_imports = import_module("/imports.star")
module = _imports.load_module("test_module")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # Check that a violation is reported for the non-private variable
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("should be stored in private variables", self.analyzer.violations[0][1])
    
    def test_load_module_private_variable(self):
        """Test that load_module results stored in private variables are valid."""
        code = """
_imports = import_module("/imports.star")
_module = _imports.load_module("test_module")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_load_module_missing_module_path(self):
        """Test that load_module calls require a module_path argument."""
        code = """
_imports = import_module("/imports.star")
_module = _imports.load_module()
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the missing module_path
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("missing required module_path argument", self.analyzer.violations[0][1])
    
    def test_load_module_with_package_id(self):
        """Test that load_module calls with package_id don't need valid relative paths."""
        code = """
_imports = import_module("/imports.star")
_module1 = _imports.load_module("invalid/path", "package-id")
_module2 = _imports.load_module(module_path="another/invalid", package_id="another-package")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported because package_id is provided
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_load_module_invalid_relative_path(self):
        """Test that load_module calls without package_id need valid relative paths."""
        code = """
_imports = import_module("/imports.star")
_module1 = _imports.load_module("../parent/reference")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # A violation should be reported for the invalid path
        self.assertEqual(len(self.analyzer.violations), 1)
        self.assertIn("Invalid module path", self.analyzer.violations[0][1])
    
    def test_load_module_valid_relative_path(self):
        """Test that load_module calls without package_id with valid relative paths."""
        code = """
_imports = import_module("/imports.star")
_module1 = _imports.load_module("test_module")
_module2 = _imports.load_module("subdir/sub_module")
"""
        node = ast.parse(code)
        self.analyzer.visit(node)
        
        # No violations should be reported
        self.assertEqual(len(self.analyzer.violations), 0)
    
    def test_load_module_non_existent_module(self):
        """Test that load_module calls to non-existent modules are reported."""
        # Create an analyzer with check_file_exists=True
        analyzer = LoadModuleAnalyzer(
            file_path=self.test_file_path,
            workspace_root=self.temp_dir,
            check_file_exists=True
        )
        
        code = """
_imports = import_module("/imports.star")
_module = _imports.load_module("non_existent_module")
"""
        node = ast.parse(code)
        analyzer.visit(node)
        
        # A violation should be reported for the non-existent module
        self.assertEqual(len(analyzer.violations), 1)
        self.assertIn("non-existent module", analyzer.violations[0][1])
    
    def test_imports_star_file(self):
        """Test that load_module calls in imports.star itself don't need private variables."""
        # Create an analyzer for imports.star
        imports_star_path = os.path.join(self.temp_dir, IMPORTS_STAR_FILENAME)
        analyzer = LoadModuleAnalyzer(
            file_path=imports_star_path,
            workspace_root=self.temp_dir,
            check_file_exists=False
        )
        
        code = """
_imports = import_module("/imports.star")
module = _imports.load_module("test_module")  # This would normally be a violation
"""
        node = ast.parse(code)
        analyzer.visit(node)
        
        # No violations should be reported because we're in imports.star
        self.assertEqual(len(analyzer.violations), 0)
    
    def test_module_exists(self):
        """Test the _module_exists method."""
        # Create an analyzer with check_file_exists=True
        analyzer = LoadModuleAnalyzer(
            file_path=self.test_file_path,
            workspace_root=self.temp_dir,
            check_file_exists=True
        )
        
        # Test existing modules
        self.assertTrue(analyzer._module_exists("/imports.star"))
        self.assertTrue(analyzer._module_exists("test_module"))
        self.assertTrue(analyzer._module_exists("test_module.star"))
        self.assertTrue(analyzer._module_exists("subdir/sub_module"))
        
        # Test non-existent modules
        self.assertFalse(analyzer._module_exists("non_existent_module"))
        self.assertFalse(analyzer._module_exists("subdir/non_existent"))


if __name__ == "__main__":
    unittest.main() 