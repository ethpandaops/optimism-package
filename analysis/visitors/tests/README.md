# Visitor Tests

This directory contains tests for the visitor classes in the `analysis/visitors` package.

## Running the Tests

You can run all the tests using the following command from the project root:

```bash
python -m unittest discover -s analysis/visitors/tests
```

Or run individual test files:

```bash
python -m analysis.visitors.tests.test_base_visitor
python -m analysis.visitors.tests.test_simple_visitor
python -m analysis.visitors.tests.test_function_collector
python -m analysis.visitors.tests.test_import_collector
python -m analysis.visitors.tests.test_import_module_analyzer
python -m analysis.visitors.tests.test_load_module_analyzer
python -m analysis.visitors.tests.test_call_analyzer
```

## Test Files

- `test_base_visitor.py`: Tests for the `BaseVisitor` class, which provides common functionality for all visitors.
- `test_simple_visitor.py`: Tests for a simple implementation of a visitor that collects variable names and checks for undefined variables.
- `test_function_collector.py`: Tests for the `FunctionCollector` class, which collects function definitions and their signatures.
- `test_import_collector.py`: Tests for the `ImportCollector` class, which collects import information from a file.
- `test_import_module_analyzer.py`: Tests for the `ImportModuleAnalyzer` class, which analyzes import_module calls and checks their arguments.
- `test_load_module_analyzer.py`: Tests for the `LoadModuleAnalyzer` class, which verifies that load_module calls without package_id have valid relative paths.
- `test_call_analyzer.py`: Tests for the `CallAnalyzer` class, which analyzes function calls and verifies they match function signatures.

## Writing New Tests

When writing tests for a new visitor:

1. Create a new test file named `test_<visitor_name>.py`
2. Import the visitor class you want to test
3. Create test cases that verify the visitor's functionality
4. Run the tests to ensure they pass

## Example

Here's a simple example of how to test a new visitor:

```python
import unittest
import ast
from analysis.visitors.your_visitor import YourVisitor

class TestYourVisitor(unittest.TestCase):
    def setUp(self):
        self.visitor = YourVisitor()
    
    def test_some_functionality(self):
        code = """
        # Your test code here
        """
        node = ast.parse(code)
        self.visitor.visit(node)
        
        # Assert expected behavior
        self.assertEqual(self.visitor.some_attribute, expected_value)

if __name__ == "__main__":
    unittest.main() 