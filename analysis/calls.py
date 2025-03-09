import sys
import os
import ast
import re
from typing import List, Tuple, Dict, Set, Optional, NamedTuple, Any

# Global verbose flag
VERBOSE = False

builtin_functions = set([
    # Starlark built-in functions
    "all", "any", "bool", "bytes", "dict", "dir", "enumerate", "fail", "float", "getattr", "hasattr",
    "hash", "int", "len", "list", "max", "min", "print", "range", "repr", "reversed", "set", "sorted",
    "str", "tuple", "type", "zip",
    # Kurtosis stdlib
    "import_module", "read_file", "struct",
    "Directory", "ExecRecipe", "GetHttpRequestRecipe", "ImageBuildSpec", "NixBuildSpec", "PortSpec",
    "PostHttpRequestRecipe", "ReadyCondition", "ServiceConfig", "StoreSpec", "Toleration", "User",
])

# Built-in modules that don't need to be checked
builtin_modules = set([
    # Kurtosis stdlib
    "json", "time",
    # Kurtosis-test modules
    "kurtosistest", "expect",
])

def debug_print(*args, **kwargs):
    """Print debug messages only when verbose mode is enabled."""
    if VERBOSE:
        print(*args, **kwargs)


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
    """Analyzes function calls in a file."""
    
    def __init__(self, 
                 file_path: str,
                 local_functions: Dict[str, FunctionSignature],
                 imports: Dict[str, ImportInfo],
                 all_functions: Dict[str, Dict[str, FunctionSignature]],
                 module_to_file: Dict[str, str]):
        self.file_path = file_path
        self.local_functions = local_functions
        self.imports = imports
        self.all_functions = all_functions  # file_path -> {function_name -> FunctionSignature}
        self.module_to_file = module_to_file  # module_path -> file_path
        self.violations = []
        
        # Initialize scope tracking
        # We use a stack of sets to track variables in different scopes
        # The first set is the global scope
        self.scope_stack = [set()]
    
    def _enter_scope(self):
        """Enter a new scope, inheriting variables from parent scope."""
        # Create a new scope that inherits all variables from the parent scope
        new_scope = set(self.scope_stack[-1])
        self.scope_stack.append(new_scope)
    
    def _exit_scope(self):
        """Exit the current scope."""
        if len(self.scope_stack) > 1:  # Always keep at least the global scope
            self.scope_stack.pop()
    
    def _add_to_current_scope(self, var_name: str):
        """Add a variable to the current scope."""
        self.scope_stack[-1].add(var_name)
    
    def _is_in_scope(self, var_name: str) -> bool:
        """Check if a variable is in the current scope."""
        return var_name in self.scope_stack[-1]
    
    def visit_Module(self, node):
        """Visit the module node (file root)."""
        # Start with a clean global scope
        self.scope_stack = [set()]
        self.generic_visit(node)
    
    def visit_FunctionDef(self, node):
        """Visit a function definition."""
        # Enter a new scope for the function
        self._enter_scope()
        
        # Add function arguments to the current scope
        for arg in node.args.args:
            self._add_to_current_scope(arg.arg)
        
        # Visit the function body
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the function scope
        self._exit_scope()
    
    def visit_ClassDef(self, node):
        """Visit a class definition."""
        # Enter a new scope for the class
        self._enter_scope()
        
        # Visit the class body
        for stmt in node.body:
            self.visit(stmt)
        
        # Exit the class scope
        self._exit_scope()
    
    def visit_For(self, node):
        """Visit a for loop."""
        # Process the iterable expression first (outside the loop scope)
        self.visit(node.iter)
        
        # Enter a new scope for the loop
        self._enter_scope()
        
        # Add loop variables to the current scope
        if isinstance(node.target, ast.Name):
            self._add_to_current_scope(node.target.id)
        elif isinstance(node.target, ast.Tuple):
            for elt in node.target.elts:
                if isinstance(elt, ast.Name):
                    self._add_to_current_scope(elt.id)
        
        # Visit the loop body
        for stmt in node.body:
            self.visit(stmt)
        
        # Visit the else clause if it exists
        if node.orelse:
            for stmt in node.orelse:
                self.visit(stmt)
        
        # Exit the loop scope
        self._exit_scope()
    
    def visit_While(self, node):
        """Visit a while loop."""
        # Process the test expression first (outside the loop scope)
        self.visit(node.test)
        
        # Enter a new scope for the loop
        self._enter_scope()
        
        # Visit the loop body
        for stmt in node.body:
            self.visit(stmt)
        
        # Visit the else clause if it exists
        if node.orelse:
            for stmt in node.orelse:
                self.visit(stmt)
        
        # Exit the loop scope
        self._exit_scope()
    
    def visit_If(self, node):
        """Visit an if statement."""
        # Process the test expression first (outside the if scope)
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
        
        # Visit the else clause if it exists
        if node.orelse:
            for stmt in node.orelse:
                self.visit(stmt)
        
        # Exit the else scope
        self._exit_scope()
    
    def visit_With(self, node):
        """Visit a with statement."""
        # Process the context expressions first (outside the with scope)
        for item in node.items:
            self.visit(item.context_expr)
            if item.optional_vars:
                self.visit(item.optional_vars)
        
        # Enter a new scope for the with block
        self._enter_scope()
        
        # Add variables from optional_vars to the current scope
        for item in node.items:
            if item.optional_vars:
                if isinstance(item.optional_vars, ast.Name):
                    self._add_to_current_scope(item.optional_vars.id)
                elif isinstance(item.optional_vars, ast.Tuple):
                    for elt in item.optional_vars.elts:
                        if isinstance(elt, ast.Name):
                            self._add_to_current_scope(elt.id)
        
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
    
    def visit_Call(self, node):
        """Visit function call nodes."""
        # Visit all arguments first to ensure any variables defined in them are in scope
        for arg in node.args:
            self.visit(arg)
        for kw in node.keywords:
            self.visit(kw.value)
        
        # Determine the function being called
        if isinstance(node.func, ast.Name):
            # Direct function call (e.g., my_function())
            func_name = node.func.id
            
            # Check if it's a local function
            if func_name in self.local_functions:
                target_signature = self.local_functions[func_name]
                self._check_call_compatibility(node, target_signature)
            # Check if it's a built-in function
            elif func_name in builtin_functions:
                # Built-in function, no need to check
                pass
            # Check if it's a variable in scope
            elif self._is_in_scope(func_name):
                # It's a variable in scope, but we can't trace it to a function
                # Skip the check as we can't determine if it's valid or not
                debug_print(f"Skipping check for function call through variable: {func_name}")
            else:
                # Not a local function, not a built-in, and not a variable in scope
                # This is definitely an error
                self.violations.append((
                    node.lineno,
                    f"Call to non-existing function or variable '{func_name}'"
                ))
        
        elif isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name):
            # Module attribute call (e.g., module.function())
            module_name = node.func.value.id
            func_name = node.func.attr
            
            # Check if this is a built-in module
            if module_name in builtin_modules:
                # Built-in module, no need to check
                debug_print(f"Skipping check for built-in module call: {module_name}.{func_name}")
                pass
            # Check if this is a call to an imported module
            elif module_name in self.imports:
                import_info = self.imports[module_name]
                
                # Only verify calls to local modules (no package_id)
                if import_info.package_id is None:
                    module_path = import_info.module_path
                    
                    # Debug logging
                    debug_print(f"Resolving call to {module_name}.{func_name} at line {node.lineno}")
                    debug_print(f"  Module path: {module_path}")
                    
                    # Try to find the target file
                    target_file = None
                    if module_path in self.module_to_file:
                        target_file = self.module_to_file[module_path]
                    else:
                        # Try with and without .star extension
                        if module_path.endswith('.star'):
                            module_path_no_ext = module_path[:-5]
                            if module_path_no_ext in self.module_to_file:
                                target_file = self.module_to_file[module_path_no_ext]
                        else:
                            module_path_with_ext = module_path + '.star'
                            if module_path_with_ext in self.module_to_file:
                                target_file = self.module_to_file[module_path_with_ext]
                    
                    if target_file and target_file in self.all_functions:
                        # Check if the function exists in the target file
                        target_functions = self.all_functions[target_file]
                        if func_name in target_functions:
                            target_signature = target_functions[func_name]
                            self._check_call_compatibility(node, target_signature)
                        else:
                            self.violations.append((
                                node.lineno,
                                f"Call to non-existing function '{module_name}.{func_name}'"
                            ))
                    else:
                        debug_print(f"  Could not find target file for module {module_path}")
            # Check if it's a variable in scope
            elif self._is_in_scope(module_name):
                # It's a variable in scope, but we can't trace what it refers to
                # Skip the check as we can't determine if it's valid or not
                debug_print(f"Skipping check for attribute call through variable: {module_name}.{func_name}")
            else:
                # Not an imported module and not a variable in scope
                # This is definitely an error
                self.violations.append((
                    node.lineno,
                    f"Call to non-existing module or variable '{module_name}'"
                ))
        else:
            # For other types of calls (e.g., complex expressions), visit the function expression
            self.visit(node.func)
    
    def _normalize_module_path(self, module_path: str) -> str:
        """Convert a module path to a file path."""
        # Remove leading slash if present
        if module_path.startswith('/'):
            module_path = module_path[1:]
        
        # If the path doesn't end with .star, add it
        if not module_path.endswith('.star'):
            module_path += '.star'
        
        # Just return the normalized path - we'll look it up in the module_to_file mapping
        return module_path
    
    def _check_call_compatibility(self, call_node: ast.Call, signature: FunctionSignature):
        """Check if a function call is compatible with the function signature."""
        # Count positional arguments
        pos_args_count = len(call_node.args)
        
        # Count required positional arguments in the signature
        required_args_count = len(signature.args) - len(signature.defaults)
        
        # Check if too few positional arguments
        if pos_args_count < required_args_count and not any(kw.arg in signature.args[:required_args_count] for kw in call_node.keywords):
            missing_args = set(signature.args[:required_args_count]) - {kw.arg for kw in call_node.keywords}
            debug_print(f"Call at line {call_node.lineno} is missing required arguments: {missing_args}")
            self.violations.append((
                call_node.lineno,
                f"Call to {signature.name} is missing required arguments: {', '.join(missing_args)}"
            ))
        
        # Check if too many positional arguments
        if pos_args_count > len(signature.args) and signature.vararg is None:
            debug_print(f"Call at line {call_node.lineno} has too many positional arguments")
            self.violations.append((
                call_node.lineno,
                f"Call to {signature.name} has too many positional arguments: got {pos_args_count}, expected at most {len(signature.args)}"
            ))
        
        # Check keyword arguments
        valid_kwargs = set(signature.args + signature.kwonlyargs)
        if signature.kwarg is None:  # Only check if **kwargs is not present
            for kw in call_node.keywords:
                if kw.arg is not None and kw.arg not in valid_kwargs:
                    debug_print(f"Call at line {call_node.lineno} has invalid keyword argument: {kw.arg}")
                    self.violations.append((
                        call_node.lineno,
                        f"Call to {signature.name} has invalid keyword argument: {kw.arg}"
                    ))


def analyze_file(file_path: str, all_functions: Dict[str, Dict[str, FunctionSignature]], module_to_file: Dict[str, str]) -> Tuple[Dict[str, FunctionSignature], List[Tuple[int, str]]]:
    """
    Analyze a file for function definitions and calls.
    
    Args:
        file_path: Path to the file to analyze
        all_functions: Dictionary mapping file paths to their function definitions
        module_to_file: Dictionary mapping module paths to file paths
        
    Returns:
        Tuple of (functions defined in this file, violations found)
    """
    try:
        debug_print(f"Analyzing calls in file: {file_path}")
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
            all_functions=all_functions,
            module_to_file=module_to_file
        )
        analyzer.visit(tree)
        
        return collector.functions, analyzer.violations
    
    except Exception as e:
        print(f"Error analyzing file {file_path}: {str(e)}")
        return {}, [(0, f"Error analyzing file {file_path}: {str(e)}")]


def find_star_files(path: str) -> List[str]:
    """Find all .star files in a directory or return the path if it's a file."""
    if os.path.isfile(path):
        if path.endswith('.star'):
            return [path]
        else:
            return []
    
    result = []
    debug_print(f"Searching for .star files in {path}")
    
    for root, _, files in os.walk(path):
        for file in files:
            if file.endswith('.star'):
                file_path = os.path.join(root, file)
                result.append(file_path)
    
    debug_print(f"Found {len(result)} .star files in {path}")
    return result


def main():
    """Main entry point for the script."""
    global VERBOSE
    
    # Parse command line arguments
    args = sys.argv[1:]
    
    # Check for -verbose flag
    if "-verbose" in args:
        VERBOSE = True
        args.remove("-verbose")
    
    if not args:
        print("Usage: python calls.py [-verbose] <file_or_directory_path> [<file_or_directory_path> ...]")
        sys.exit(1)
    
    # First pass: collect all function definitions
    all_functions: Dict[str, Dict[str, FunctionSignature]] = {}
    all_files = []
    
    for path in args:
        # Find all .star files if path is a directory
        files = find_star_files(path)
        all_files.extend(files)
    
    print(f"Found {len(all_files)} .star files to analyze")
    debug_print(f"Current working directory: {os.getcwd()}")
    
    # Create a mapping from module paths to file paths
    module_to_file = {}
    for file_path in all_files:
        # Convert file path to module path
        rel_path = os.path.relpath(file_path, os.getcwd())
        module_path = rel_path
        module_to_file[module_path] = file_path
        
        # Also add the path without .star extension
        if module_path.endswith('.star'):
            module_path_no_ext = module_path[:-5]
            module_to_file[module_path_no_ext] = file_path
    
    debug_print("Module to file mapping:")
    for module_path, file_path in module_to_file.items():
        debug_print(f"  {module_path} -> {file_path}")
    
    # First pass: collect all function definitions
    print("First pass: collecting function definitions...")
    for file_path in all_files:
        try:
            debug_print(f"Analyzing file: {file_path}")
            with open(file_path, 'r') as f:
                source = f.read()
            
            tree = ast.parse(source, filename=file_path)
            collector = FunctionCollector(file_path)
            collector.visit(tree)
            
            all_functions[file_path] = collector.functions
            debug_print(f"  Found {len(collector.functions)} functions")
            for func_name, func_sig in collector.functions.items():
                debug_print(f"    {func_name}: {func_sig}")
        except Exception as e:
            print(f"Error analyzing {file_path}: {str(e)}")
    
    # Second pass: analyze function calls
    print("\nSecond pass: analyzing function calls...")
    files_with_violations = 0
    total_violations = 0
    
    for file_path in all_files:
        _, violations = analyze_file(file_path, all_functions, module_to_file)
        
        if violations:
            files_with_violations += 1
            total_violations += len(violations)
            for line, message in violations:
                print(f"{file_path}:{line}: {message}")
        else:
            debug_print(f"No violations in {file_path}")
    
    print(f"\nAnalysis complete: found {total_violations} violations in {files_with_violations} files")
    
    if files_with_violations > 0:
        sys.exit(1)
    else:
        print("No violations found")
        sys.exit(0)


if __name__ == "__main__":
    main()
