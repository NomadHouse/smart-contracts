// This file is needed because many of our hardhat tasks rely on typechain, creating a circular dependency.

import "@typechain/hardhat";

import { HardhatUserConfig } from "hardhat/config";

import { compilers } from "./hardhat.common";

const config: HardhatUserConfig = {
  solidity: {
    compilers,
  },
};

export default config;
