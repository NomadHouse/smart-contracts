import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumber } from "ethers";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  const titleSearchUri =
    "https://gateway.pinata.cloud/ipfs/QmQ2aMEegRGynCMJZfu3HWKjMwBQKiB1vVBgAwH7Ga1yfK/";

  const operator = "0x90F79bf6EB2c4f870365E785982E1f101E93b906"; // FAKE (hardhat signer index=3)
  // const operator = "0xF1197352B990E27aF055313AAc157A8472851ed8"; // KOVAN Address
  const { address: linkToken } = await deployments.get("TestLinkToken");
  // const linkToken = "0xa36085F69e2889c224210F603D836748e7dC0088"; // KOVAN Address

  await deployments.deploy("NFT", {
    contract: "Collection",
    from: deployer,
    args: [operator, linkToken, titleSearchUri],
    log: true,
  });
};

func.tags = ["NFT", "production"];
func.dependencies = [];

export default func;
