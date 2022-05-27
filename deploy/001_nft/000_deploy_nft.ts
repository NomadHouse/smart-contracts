import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumber } from "ethers";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  const titleSearchUri =
    "https://gateway.pinata.cloud/ipfs/QmUqHaZghseJCSnrR2ivXX6Nq6LJv2fVw1kXnPTpL7gNNn/";

  // const oracle = "0x90F79bf6EB2c4f870365E785982E1f101E93b906"; // FAKE
  const oracle = "0x094C858cF9428a4c18023AA714d3e205b6Db6354"; // KOVAN Address
  // const { address: linkToken } = await deployments.get("TestLinkToken");
  const linkToken = "0xa36085F69e2889c224210F603D836748e7dC0088"; // KOVAN Address

  await deployments.deploy("NFT", {
    contract: "Collection",
    from: deployer,
    args: [oracle, linkToken, titleSearchUri],
    log: true,
  });
};

func.tags = ["NomadHouse", "NFT"];
func.dependencies = [];

export default func;
