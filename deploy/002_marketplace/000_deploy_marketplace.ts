import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

export const FEE_PERCENT = 2;

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  const { address: nft } = await deployments.get("TestNFT");
  // const { address: nft } = await deployments.get("NFT");

  await deployments.deploy("Marketplace", {
    contract: "Marketplace",
    from: deployer,
    args: [nft, FEE_PERCENT],
    log: true,
  });
};

func.tags = ["Marketplace", "production"];
func.dependencies = ["NFT"];

export default func;
