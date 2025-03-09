_PACKAGES = {
    "ethereum-package": struct(
        id = "github.com/ethpandaops/ethereum-package",
        version  = "4.5.0",
    ),
    "prometheus-package": struct(
        id = "github.com/kurtosis-tech/prometheus-package",
        version  = "f5ce159aec728898e3deb827f6b921f8ecfc527f",
    ),
    "postgres-package": struct(
        id = "github.com/kurtosis-tech/postgres-package",
        version  = "2d363be1bc42524f6b0575cac0bbc0fd194ae173",
    ),
}


def load_module(module_path, package_id=None):
    """Load a module from a package.

    Args:
        module_path(str): The path to the module to load. It must be relative to the package root.
        package_id(str): The ID of the package to load the module from. If not provided, the module will be loaded from the current package.

    Returns:
        The loaded module.
    """
    pkg = struct(id = "", version = None)
    if package_id:
        pkg = _PACKAGES[package_id]
    locator = "{0}/{1}".format(pkg.id, module_path)
    if pkg.version:
        locator = "{0}@{1}".format(locator, pkg.version)
    return import_module(locator)


ext = struct(
    ethereum_package = load_module("main.star", "ethereum-package"),
    ethereum_package_shared_utils = load_module("src/shared_utils/shared_utils.star", "ethereum-package"),
    ethereum_package_constants = load_module("src/package_io/constants.star", "ethereum-package"),
)
