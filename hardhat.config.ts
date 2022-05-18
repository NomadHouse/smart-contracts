import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-solhint";
import "hardhat-deploy";
import "hardhat-contract-sizer";
import "hardhat-abi-exporter";
import "hardhat-docgen";
import "@tenderly/hardhat-tenderly";
import "hardhat-gas-reporter";
import "@openzeppelin/hardhat-upgrades";
import { HardhatUserConfig } from "hardhat/types";

import { BigNumber } from "ethers";

const gwei = 1000000000;

const ETHERSCAN_API_KEY =
  process.env["ETHERSCAN_API_KEY"] || "CH7M2ATCZABP2GIHEF3FREWWQPDFQBSH8G";

export const config: HardhatUserConfig = {
  paths: {
    artifacts: "./dist/artifacts",
  },
  gasReporter: {
    enabled: !!process.env.REPORT_GAS,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.3",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    minter: {
      default: 1,
    },
  },
  networks: {
    localhost: {
      live: false,
      saveDeployments: true,
      tags: ["local"],
    },
    hardhat: {
      live: false,
      saveDeployments: false,
      tags: ["test", "local"],
      blockGasLimit: 20_000_000, // polygon limit
      gas: 20_000_000, // hardcoded because ganache ignores the per-tx gasLimit override
    },
    polygon: {
      live: true,
      url: "https://polygon-rpc.com",
      // url: "https://rpc-mainnet.maticvigil.com/v1/9714a1ac19043ceba4e9515077fe8e17164298cb",
      chainId: 137,
      // gasPrice: gwei * 350,
    },
    mumbai: {
      live: true,
      url: "https://polygon-mumbai.infura.io/v3/439f9f2589514c8fb75a894385c1cab0",
      chainId: 80001,
    },
    mainnet: {
      live: true,
      url: "https://mainnet.infura.io/v3/439f9f2589514c8fb75a894385c1cab0",
      chainId: 1,
    },
  },
  // etherscan: {
  // apiKey: ETHERSCAN_API_KEY,
  // },
};

const PRIVATE_KEY = process.env["PRIVATE_KEY"];
if (PRIVATE_KEY && config.networks) {
  for (const networkName of Object.keys(config.networks)) {
    const network = config.networks[networkName];
    if (networkName !== "hardhat" && network) network.accounts = [PRIVATE_KEY];
  }
}

export default config;
