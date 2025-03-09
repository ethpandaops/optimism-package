import ast
import sys
import os
import glob
import re
from typing import List, Tuple, Dict, Set, Optional, NamedTuple, Any


class FunctionSignature(NamedTuple):
    """Represents a function signature with its parameters."""
    name: str
    file_path: str
    lineno: int
    args: List[str]  # Positional argument names
    defaults: List[Any]  # Default values for optional arguments
    kwonlyargs: List[str]  # Keyword-only argument names
    kwdefaults: Dict[str, Any]  # Default values for keyword-only arguments
    vararg: Optional[str]  # *args parameter name
    kwarg: Optional[str]  # **kwargs parameter name
    
    def __str__(self) -> str:
        """String representation of the function signature."""
        parts = []
        
        # Add positional arguments
        required_args_count = len(self.args) - len(self.defaults)
        for i, arg in enumerate(self.args):
            if i >= required_args_count:
                default_idx = i - required_args_count
                default_val = self.defaults[default_idx]
                parts.append(f"{arg}={ast.unparse(default_val) if isinstance(default_val, ast.AST) else repr(default_val)}")
            else:
                parts.append(arg)
        
        # Add *args if present
        if self.vararg:
            parts.append(f"*{self.vararg}")
        
        # Add keyword-only arguments
        for arg in self.kwonlyargs:
            if arg in self.kwdefaults and self.kwdefaults[arg] is not None:
                default_val = self.kwdefaults[arg]
                parts.append(f"{arg}={ast.unparse(default_val) if isinstance(default_val, ast.AST) else repr(default_val)}")
            else:
                parts.append(f"{arg}")
        
        # Add **kwargs if present
        if self.kwarg:
            parts.append(f"**{self.kwarg}")
        
        return f"{self.name}({', '.join(parts)})"


class ImportInfo(NamedTuple):
    """Information about an import statement."""
    module_path: str
    package_id: Optional[str]
    imported_names: Dict[str, str]  # Mapping of local name to original name


class FunctionCollector(ast.NodeVisitor):
    """Collects function definitions from a file."""
    
    def __init__(self, file_path: str):
        self.file_path = file_path
        self.functions: Dict[str, FunctionSignature] = {}
    
    def visit_FunctionDef(self, node):
        """Visit function definition nodes."""
        # Extract function signature information
        args = node.args
        
        # Get positional arguments
        pos_args = [arg.arg for arg in args.args]
        
        # Get default values for optional arguments
        defaults = args.defaults
        
        # Get *args parameter
        vararg = args.vararg.arg if args.vararg else None
        
        # Get keyword-only arguments
        kwonlyargs = [arg.arg for arg in args.kwonlyargs]
        
        # Get default values for keyword-only arguments
        kwdefaults = {}
        if args.kw_defaults:
            for i, default in enumerate(args.kw_defaults):
                if default is not None:
                    kwdefaults[kwonlyargs[i]] = default
        
        # Get **kwargs parameter
        kwarg = args.kwarg.arg if args.kwarg else None
        
        # Create function signature
        signature = FunctionSignature(
            name=node.name,
            file_path=self.file_path,
            lineno=node.lineno,
            args=pos_args,
            defaults=defaults,
            kwonlyargs=kwonlyargs,
            kwdefaults=kwdefaults,
            vararg=vararg,
            kwarg=kwarg
        )
        
        # Store function signature
        self.functions[node.name] = signature
        
        # Continue visiting child nodes
        self.generic_visit(node)


class ImportCollector(ast.NodeVisitor):
    """Collects import information from a file."""
    
    def __init__(self):
        self.imports: Dict[str, ImportInfo] = {}  # Variable name -> ImportInfo
        self.import_module_vars: Set[str] = set()  # Variables assigned from import_module("/imports.star")
    
    def visit_Assign(self, node):
        """Visit assignment nodes to track imports."""
        # Check if this is an assignment from import_module
        if (isinstance(node.value, ast.Call) and 
            isinstance(node.value.func, ast.Name) and 
            node.value.func.id == 'import_module'):
            
            # Check if it's importing "/imports.star"
            if (len(node.value.args) == 1 and 
                isinstance(node.value.args[0], ast.Constant) and 
                isinstance(node.value.args[0].value, str) and 
                node.value.args[0].value == "/imports.star"):
                
                # Add all target variables to our tracked set
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        self.import_module_vars.add(target.id)
        
        # Check if this is an assignment from VARIABLE.load_module
        elif (isinstance(node.value, ast.Call) and 
              isinstance(node.value.func, ast.Attribute) and 
              node.value.func.attr == 'load_module' and
              isinstance(node.value.func.value, ast.Name) and
              node.value.func.value.id in self.import_module_vars):
            
            # Extract module_path and package_id
            module_path = None
            package_id = None
            
            # Get module_path from positional or keyword arguments
            if len(node.value.args) >= 1:
                arg = node.value.args[0]
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                    module_path = arg.value
            
            for kw in node.value.keywords:
                if kw.arg == 'module_path' and isinstance(kw.value, ast.Constant) and isinstance(kw.value.value, str):
                    module_path = kw.value.value
                elif kw.arg == 'package_id' and isinstance(kw.value, ast.Constant) and isinstance(kw.value.value, str):
                    package_id = kw.value.value
            
            # Get package_id from second positional argument if present
            if len(node.value.args) >= 2 and package_id is None:
                arg = node.value.args[1]
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                    package_id = arg.value
            
            # If we have a valid module_path, record the import
            if module_path:
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        # For now, assume all names from the module are imported
                        # This is a simplification; in a real implementation, we'd need to analyze
                        # the imported module to get the actual exported names
                        self.imports[target.id] = ImportInfo(
                            module_path=module_path,
                            package_id=package_id,
                            imported_names={}  # Will be populated later if needed
                        )
        
        # Continue visiting child nodes
        self.generic_visit(node)
    
    def visit_ImportFrom(self, node):
        """Visit import from statements."""
        # Standard Python imports are not our focus, but we'll track them for completeness
        if node.module:
            imported_names = {}
            for name in node.names:
                imported_names[name.asname or name.name] = name.name
            
            # We don't have package_id for standard imports
            self.imports[node.module] = ImportInfo(
                module_path=node.module,
                package_id=None,
                imported_names=imported_names
            )
        
        # Continue visiting child nodes
        self.generic_visit(node)


class CallAnalyzer(ast.NodeVisitor):
    """Analyzes function calls and verifies they match their definitions."""
    
    def __init__(self, 
                 file_path: str,
                 local_functions: Dict[str, FunctionSignature],
                 imports: Dict[str, ImportInfo],
                 all_functions: Dict[str, Dict[str, FunctionSignature]]):
        self.file_path = file_path
        self.local_functions = local_functions
        self.imports = imports
        self.all_functions = all_functions  # file_path -> {function_name -> FunctionSignature}
        self.violations = []
    
    def visit_Call(self, node):
        """Visit function call nodes."""
        # Determine the function being called
        if isinstance(node.func, ast.Name):
            # Direct function call (e.g., my_function())
            func_name = node.func.id
            target_signature = self._resolve_function(func_name)
            
            if target_signature:
                self._check_call_compatibility(node, target_signature)
        
        elif isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name):
            # Module attribute call (e.g., module.function())
            module_name = node.func.value.id
            func_name = node.func.attr
            
            # Check if this is a call to an imported module
            if module_name in self.imports:
                import_info = self.imports[module_name]
                
                # Only verify calls to local modules (no package_id)
                if import_info.package_id is None:
                    # Normalize the module path to get the file path
                    target_file = self._normalize_module_path(import_info.module_path)
                    
                    # Look for the function in the target file
                    if target_file in self.all_functions and func_name in self.all_functions[target_file]:
                        target_signature = self.all_functions[target_file][func_name]
                        self._check_call_compatibility(node, target_signature)
        
        # Continue visiting child nodes
        self.generic_visit(node)
    
    def _resolve_function(self, func_name: str) -> Optional[FunctionSignature]:
        """Resolve a function name to its signature."""
        # Check local functions first
        if func_name in self.local_functions:
            return self.local_functions[func_name]
        
        # If not found locally, it might be imported
        # This is a simplified approach; a more complete implementation would
        # track imported names more precisely
        return None
    
    def _normalize_module_path(self, module_path: str) -> str:
        """Convert a module path to a file path."""
        # Remove leading slash if present
        if module_path.startswith('/'):
            module_path = module_path[1:]
        
        # If the path doesn't end with .star, add it
        if not module_path.endswith('.star'):
            module_path += '.star'
        
        # Resolve relative to the current file's directory
        base_dir = os.path.dirname(self.file_path)
        return os.path.normpath(os.path.join(base_dir, module_path))
    
    def _check_call_compatibility(self, call_node: ast.Call, signature: FunctionSignature):
        """Check if a function call is compatible with the function signature."""
        # Count positional arguments
        pos_args_count = len(call_node.args)
        
        # Count required positional arguments in the signature
        required_args_count = len(signature.args) - len(signature.defaults)
        
        # Check if too few positional arguments
        if pos_args_count < required_args_count and not any(kw.arg in signature.args[:required_args_count] for kw in call_node.keywords):
            missing_args = set(signature.args[:required_args_count]) - {kw.arg for kw in call_node.keywords}
            self.violations.append((
                call_node.lineno,
                f"Call to {signature.name} is missing required arguments: {', '.join(missing_args)}"
            ))
        
        # Check if too many positional arguments
        if pos_args_count > len(signature.args) and signature.vararg is None:
            self.violations.append((
                call_node.lineno,
                f"Call to {signature.name} has too many positional arguments: got {pos_args_count}, expected at most {len(signature.args)}"
            ))
        
        # Check keyword arguments
        valid_kwargs = set(signature.args + signature.kwonlyargs)
        if signature.kwarg is None:  # Only check if the function doesn't accept **kwargs
            for kw in call_node.keywords:
                if kw.arg is not None and kw.arg not in valid_kwargs:
                    self.violations.append((
                        call_node.lineno,
                        f"Call to {signature.name} uses unexpected keyword argument '{kw.arg}'"
                    ))


def analyze_file(file_path: str, all_functions: Dict[str, Dict[str, FunctionSignature]]) -> Tuple[Dict[str, FunctionSignature], List[Tuple[int, str]]]:
    """
    Analyze a file for function definitions and calls.
    
    Args:
        file_path: Path to the file to analyze
        all_functions: Dictionary mapping file paths to their function definitions
        
    Returns:
        Tuple of (functions defined in this file, violations found)
    """
    try:
        with open(file_path, 'r') as f:
            source = f.read()
        
        # Parse the source code into an AST
        tree = ast.parse(source, filename=file_path)
        
        # First pass: collect function definitions
        collector = FunctionCollector(file_path)
        collector.visit(tree)
        
        # Collect import information
        import_collector = ImportCollector()
        import_collector.visit(tree)
        
        # Second pass: analyze function calls
        analyzer = CallAnalyzer(
            file_path=file_path,
            local_functions=collector.functions,
            imports=import_collector.imports,
            all_functions=all_functions
        )
        analyzer.visit(tree)
        
        return collector.functions, analyzer.violations
    
    except Exception as e:
        return {}, [(0, f"Error analyzing file {file_path}: {str(e)}")]


def find_star_files(path: str) -> List[str]:
    """
    Find all *.star files in the given path recursively.
    
    Args:
        path: Directory path to search
        
    Returns:
        List of paths to *.star files
    """
    if os.path.isfile(path):
        return [path] if path.endswith('.star') else []
    
    star_files = []
    for root, _, _ in os.walk(path):
        star_files.extend(glob.glob(os.path.join(root, "*.star")))
    
    return star_files


def main():
    """Main entry point for the script."""
    if len(sys.argv) < 2:
        print("Usage: python calls.py <file_or_directory_path> [<file_or_directory_path> ...]")
        sys.exit(1)
    
    # First pass: collect all function definitions
    all_functions: Dict[str, Dict[str, FunctionSignature]] = {}
    all_files = []
    
    for path in sys.argv[1:]:
        # Find all .star files if path is a directory
        files = find_star_files(path)
        all_files.extend(files)
    
    print(f"Found {len(all_files)} .star files to analyze")
    
    # First pass: collect all function definitions
    print("First pass: collecting function definitions...")
    for file_path in all_files:
        try:
            with open(file_path, 'r') as f:
                source = f.read()
            
            tree = ast.parse(source, filename=file_path)
            collector = FunctionCollector(file_path)
            collector.visit(tree)
            
            all_functions[file_path] = collector.functions
        except Exception as e:
            print(f"Error analyzing {file_path}: {str(e)}")
    
    # Count total functions found
    total_functions = sum(len(funcs) for funcs in all_functions.values())
    print(f"Found {total_functions} function definitions")
    
    # Second pass: analyze function calls
    print("Second pass: analyzing function calls...")
    files_with_violations = 0
    total_violations = 0
    
    for file_path in all_files:
        _, violations = analyze_file(file_path, all_functions)
        
        if violations:
            files_with_violations += 1
            total_violations += len(violations)
            print(f"\nViolations in {file_path}:")
            for line, message in violations:
                print(f"  Line {line}: {message}")
    
    print(f"\nAnalysis complete: found {total_violations} violations in {files_with_violations} files")
    
    if files_with_violations > 0:
        sys.exit(1)
    else:
        print("No violations found")
        sys.exit(0)


if __name__ == "__main__":
    main()
