import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getChainId } from "hardhat";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments } = hre;

  const chainId = parseInt(await getChainId());

  const blockNumbers: number[] = [];
  const d = async (name: string) => {
    const { address, receipt } = await deployments.get(name);
    if (receipt) blockNumbers.push(receipt.blockNumber);
    return address;
  };

  const nft = await d("NFT");
  const marketplace = await d("Marketplace");

  console.log(
    JSON.stringify(
      {
        chainId,
        uploadBlock: lowest(blockNumbers),
        addresses: {
          nft,
          marketplace,
        },
      },
      null,
      2
    )
  );
};

func.runAtTheEnd = true;
func.tags = ["Print"];

export default func;

function lowest(arr: number[]): number | undefined {
  if (arr.length === 0) return;

  let lowest = arr[0];
  for (const n of arr.slice(0)) {
    if (n < lowest) lowest = n;
  }
  return lowest;
}
