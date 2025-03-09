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


def _load_module(module_path, package_id=None):
    pkg = struct(id = "", version = None)
    if package_id:
        pkg = _PACKAGES[package_id]
    locator = "{0}/{1}".format(pkg.id, module_path)
    if pkg.version:
        locator = "{0}@{1}".format(locator, pkg.version)
    return import_module(locator)


ext = struct(
    ethereum_package = _load_module("main.star", "ethereum-package"),
    ethereum_package_shared_utils = _load_module("src/shared_utils/shared_utils.star", "ethereum-package"),
    ethereum_package_constants = _load_module("src/package_io/constants.star", "ethereum-package"),
    ethereum_package_cl_context = _load_module("src/cl/cl_context.star", "ethereum-package"),
    ethereum_package_el_context = _load_module("src/el/el_context.star", "ethereum-package"),
    ethereum_package_el_admin_node_info = _load_module("src/el/el_admin_node_info.star", "ethereum-package"),
    ethereum_package_input_parser = _load_module("src/package_io/input_parser.star", "ethereum-package"),
    ethereum_package_genesis_constants = _load_module("src/prelaunch_data_generator/genesis_constants/genesis_constants.star", "ethereum-package"),
    ethereum_package_node_metrics = _load_module("src/node_metrics_info.star", "ethereum-package"),

    postgres_package = _load_module("main.star", "postgres-package"),
    prometheus_package = _load_module("main.star", "prometheus-package"),
)

def load_module(module_path):
    """Load a module from the current package.

    Args:
        module_path(str): The path to the module to load. It must be relative to the package root.

    Returns:
        The loaded module.
    """
    return _load_module(module_path)
