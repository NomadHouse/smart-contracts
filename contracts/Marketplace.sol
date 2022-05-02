// contracts/NFTMarketplace.sol
// SPDX-License-Identifier: MIT OR Apache-2.0

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IMarketplace.sol";

contract Marketplace is ReentrancyGuard {
  using Counters for Counters.Counter;

  address payable public marketowner;

  mapping(uint256 => MarketItem) private marketItems;

  constructor() {
    marketowner = payable(msg.sender);
  }

}