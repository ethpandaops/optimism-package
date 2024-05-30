input_parser = import_module("./src/package_io/input_parser.star")
ethereum_package = import_module("github.com/kurtosis-tech/ethereum-package/main.star@add-arbitrary-contract-def")

def run(plan,args={}):
    """Deploy a Optimism L2 with a local L1.

    Args:
        args(yaml): Configures other aspects of the environment.
    Returns:
        A full deployment of Optimism L2
    """

    # Parse the values for the args
    plan.print("Parsing the L1 input args")

    ethereum_args = args["ethereum_package"]

    # Deploy the L1
    plan.print("Deploying a local L1")
    ethereum_package.run(plan, ethereum_args)

    # Parse the values for the args
    plan.print("Parsing the L2 input args")
    optimism_args = args["optimism_package"]

    # Deploy the L2
    plan.print("Deploying a local L2")
    args_with_right_defaults = input_parser.input_parser(plan, optimism_args)
    plan.print(args_with_right_defaults)

