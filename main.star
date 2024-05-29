input_parser = import_module("./input_parser.star")
ethereum_package = import_module("./dependencies/ethereum.star")
constants = import_module("./dependencies/constants.star")

def run(plan,args={}):
    """Deploy a Optimism L2 with a local L1.

    Args:
        args(json): Configures other aspects of the environment.
    Returns:
        A full deployment of Optimism L2
    """

    # Parse the values for the args
    args_with_right_defaults = input_parser.input_parser(plan, args)

    # Deploy the L1
    plan.print("Deploying a local L1")
    ethereum_package.run(plan, args)


