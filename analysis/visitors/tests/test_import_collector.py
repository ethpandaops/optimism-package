import unittest
import ast

from analysis.visitors.import_collector import ImportCollector
from analysis.visitors.common import ImportInfo


class TestImportCollector(unittest.TestCase):
    """Test cases for the ImportCollector class."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.collector = ImportCollector()
    
    def test_import_module_tracking(self):
        """Test tracking variables assigned from import_module('/imports.star')."""
        code = """
imports = import_module("/imports.star")
other_var = import_module("/some/other/module.star")
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that 'imports' is tracked as an import_module var
        self.assertIn("imports", self.collector.import_module_vars)
        
        # Check that 'other_var' is not tracked (wrong path)
        self.assertNotIn("other_var", self.collector.import_module_vars)
    
    def test_load_module_tracking(self):
        """Test tracking variables assigned from VARIABLE.load_module()."""
        code = """
imports = import_module("/imports.star")
ethereum = imports.load_module("ethereum", "ethereum-package")
optimism = imports.load_module(module_path="optimism", package_id="optimism-package")
no_package = imports.load_module("no-package")
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that all variables are tracked correctly
        self.assertIn("ethereum", self.collector.imports)
        self.assertIn("optimism", self.collector.imports)
        self.assertIn("no_package", self.collector.imports)
        
        # Check the import info for ethereum
        ethereum_import = self.collector.imports["ethereum"]
        self.assertEqual(ethereum_import.module_path, "ethereum")
        self.assertEqual(ethereum_import.package_id, "ethereum-package")
        
        # Check the import info for optimism
        optimism_import = self.collector.imports["optimism"]
        self.assertEqual(optimism_import.module_path, "optimism")
        self.assertEqual(optimism_import.package_id, "optimism-package")
        
        # Check the import info for no_package
        no_package_import = self.collector.imports["no_package"]
        self.assertEqual(no_package_import.module_path, "no-package")
        self.assertIsNone(no_package_import.package_id)
    
    def test_derived_variables_tracking(self):
        """Test tracking variables derived from import_module vars."""
        code = """
imports = import_module("/imports.star")
ext = imports.ext
ethereum_package = ext.ethereum_package
direct_assign = imports.ext.optimism_package
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that derived variables are tracked correctly
        self.assertIn("ext", self.collector.imports_derived_vars)
        self.assertEqual(self.collector.imports_derived_vars["ext"], "imports")
        
        self.assertIn("ethereum_package", self.collector.imports_derived_vars)
        self.assertEqual(self.collector.imports_derived_vars["ethereum_package"], "ext")
        
        self.assertIn("direct_assign", self.collector.imports_derived_vars)
        self.assertEqual(self.collector.imports_derived_vars["direct_assign"], "imports")
    
    def test_import_from_tracking(self):
        """Test tracking standard Python import from statements."""
        code = """
from os import path, environ as env
from sys import argv
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check that modules are tracked
        self.assertIn("os", self.collector.imports)
        self.assertIn("sys", self.collector.imports)
        
        # Check the import info for os
        os_import = self.collector.imports["os"]
        self.assertEqual(os_import.module_path, "os")
        self.assertIsNone(os_import.package_id)
        self.assertEqual(os_import.imported_names, {"path": "path", "env": "environ"})
        
        # Check the import info for sys
        sys_import = self.collector.imports["sys"]
        self.assertEqual(sys_import.module_path, "sys")
        self.assertIsNone(sys_import.package_id)
        self.assertEqual(sys_import.imported_names, {"argv": "argv"})
    
    def test_complex_import_scenario(self):
        """Test a complex scenario with multiple import types."""
        code = """
# Import the imports module
imports = import_module("/imports.star")

# Load modules using different syntaxes
ethereum = imports.load_module("ethereum", "ethereum-package")
optimism = imports.load_module(module_path="optimism", package_id="optimism-package")

# Derived variables
ext = imports.ext

# Standard Python imports
from os import path
import sys
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # Check import_module vars
        self.assertIn("imports", self.collector.import_module_vars)
        
        # Check load_module imports
        self.assertIn("ethereum", self.collector.imports)
        self.assertIn("optimism", self.collector.imports)
        
        # Check derived vars - only direct assignments from import_module vars are tracked
        self.assertIn("ext", self.collector.imports_derived_vars)
        
        # Check standard imports
        self.assertIn("os", self.collector.imports)
    
    def test_invalid_imports(self):
        """Test handling of invalid or non-standard imports."""
        code = """
# Not a valid import_module call (wrong function name)
imports1 = load_module("/imports.star")

# Not a valid import_module call (wrong path)
imports2 = import_module("wrong_path")

# Not a valid load_module call (not from an import_module var)
module = some_var.load_module("module")

# Not a valid derived variable (not from an import_module var)
ext = some_var.ext
"""
        node = ast.parse(code)
        self.collector.visit(node)
        
        # None of these should be tracked
        self.assertNotIn("imports1", self.collector.import_module_vars)
        self.assertNotIn("imports2", self.collector.import_module_vars)
        self.assertNotIn("module", self.collector.imports)
        self.assertNotIn("ext", self.collector.imports_derived_vars)


if __name__ == "__main__":
    unittest.main() 