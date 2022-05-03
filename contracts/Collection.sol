// contracts/Collection.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Collection is 
    ERC1155,
    ReentrancyGuard
  {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    struct Deed {
      uint id;
      address payable owner;
      bool verified;
    }

    
    // Key value pair containing a list of deeds in the contract
    mapping(uint256 => Deed) private deedRegistry;


    constructor() ERC1155("") {
    }

    function verifyDeedOwnership(uint256 deedId) internal {
      // Chainlink GET request here
      
    }

    function mintDeed(
      address account,
      bytes memory data
    ) external payable nonReentrant {
      
    }

    function batchMintDeed(
      address account,
      bytes memory data
    ) external payable nonReentrant {
      
    }

    function mintFraction(
      address account,
      bytes memory data
    ) external payable nonReentrant {
      
    }

    function batchMintFraction(
      address account,
      bytes memory data
    ) external payable nonReentrant {
      
    }

    
}