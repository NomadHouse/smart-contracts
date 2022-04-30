// contracts/PropertyFraction.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PropertyFraction is 
    ERC1155,
    ReentrancyGuard
  {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

  constructor() ERC1155("") {
  }
    
}