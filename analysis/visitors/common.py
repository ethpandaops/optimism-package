"""
Common types and constants for AST analysis.

This module contains common types and constants used by various visitors.
"""

from typing import Dict, List, Set, Optional, NamedTuple, Any

# Built-in functions that don't need to be checked
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
    "plan", "json", "time",
    # Kurtosis-test modules
    "kurtosistest", "expect",
])

# Special methods that are known to be valid on imports module
imports_valid_methods = set([
    "load_module", "ext",
])


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
        """Return a string representation of the function signature."""
        parts = []
        
        # Add positional arguments
        for i, arg in enumerate(self.args):
            if i >= len(self.args) - len(self.defaults):
                # This is an optional argument with a default value
                default_idx = i - (len(self.args) - len(self.defaults))
                default_value = self.defaults[default_idx]
                parts.append(f"{arg}={repr(default_value)}")
            else:
                # This is a required argument
                parts.append(arg)
        
        # Add *args if present
        if self.vararg:
            parts.append(f"*{self.vararg}")
        
        # Add keyword-only arguments
        for arg in self.kwonlyargs:
            if arg in self.kwdefaults and self.kwdefaults[arg] is not None:
                parts.append(f"{arg}={repr(self.kwdefaults[arg])}")
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