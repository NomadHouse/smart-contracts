// contracts/Marketplace.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Marketplace is ReentrancyGuard {
  using Counters for Counters.Counter;

  address payable public marketOwner;
  address nftContract;

  enum MarketItemState { Listed, Release, Inactive }

  struct MarketItem {
    uint id;
    uint256 tokenId;
    address payable seller;
    address payable buyer;
    uint256 price;
    MarketItemState state;
  }

  event MarketItemListed (
    uint indexed id,
    uint256 indexed tokenId,
    uint256 price,
    MarketItemState state
  );

  event MarketItemSold (
    uint indexed id,
    uint256 indexed tokenId,
    address seller,
    address buyer,
    uint256 price,
    MarketItemState state
  );


  mapping(uint256 => MarketItem) private marketItems;

  constructor() {
    marketOwner = payable(msg.sender);
    nftContract = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8; //replace this with Collection.sol address
  }

}