import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  await deployments.deploy("TestLinkToken", {
    contract: "TestLinkToken",
    from: deployer,
    args: [],
    log: true,
  });
};

func.tags = ["LinkToken", "test"];
func.dependencies = [];

export default func;
