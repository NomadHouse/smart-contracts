// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @author : Fuzzb0t

interface IMarketplace {

  enum ItemState { Created, Release, Inactive }

  struct MarketItem {
    uint id;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable buyer;
    uint256 price;
    ItemState state;
  }

  event MarketItemCreated (
    uint indexed id,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address buyer,
    uint256 price,
    ItemState state
  );

  event MarketItemSold (
    uint indexed id,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address buyer,
    uint256 price,
    ItemState state
  );

}