// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; //=> https://docs.openzeppelin.com/contracts/2.x/api/ownership
import "@openzeppelin/contracts/utils/Address.sol"; //=> https://docs.openzeppelin.com/contracts/4.x/api/utils#Address
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; //=> https://docs.openzeppelin.com/contracts/2.x/api/math

// * Address Library
/** Provide more operations related to the address native data type
  - Isn't easy to know wether an address the smart contract is dealing with is an actual wallet or another smart contact.
  - Provides a function called isContract() wich returns a boolean answering that question.
 */

// * Ownable Library
/**
  - Implements the premise that the address that deployed the smart contract is the owner of the contract
  - Certain functions can only be called by the owner
  - We can call for example inside a function "onlyOwner" => function restrictedFunc() public onlyOwner {...} => Only the owner of the contract can use this function.
  - Code beghind onlyOwner:
  modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
 */

// * Counters Utility
/** A simple way to get a counter that can only be incremented or decremented
  - Provides counters that can only be incremented or decremented by one.
  - Functions that includes:
    - current() => Take the current value of the counter.
    - increment() => Increment the counter by one.
    - decrement() => Decrement the counter by one.
 */

// * ReentrancyGuard
/** ReentrancyGuard is used to prevent reentrancy attacks.
  - It has one modifier => nonReentrant() - We can use this in a widraw() function.
  - And one function => constructor()
  */

// * Uses of the smart contract [SELLER]
/**
  - Approve an NFT to market contract
  - Create a market item with listing fee
  - Wait for a buyer to buy the NFT
  - Receive the price value of the NFT
   */

// * Uses of the smart contract [BUYER]
/**
  - Buy an NFT from the market contract paying the price value
  */

// * Purchase process
/**
  - Transfer the price value to the seller
  - Transfer the NFT from the seller to the buyer
  - Transfer the listing fee to the market owner
  - Change marketItemState from Created to Release
   */

// ! We will wait until the item is sold to transfer the NFT from the seller to the buyer

// * Handle Errors (If I'm not wrong, this saves gas when showing errors and not using Strings for it)
// Example of error with parameters => error InsufficientBalance(uint256 available, uint256 required);
/** Using them on the function:
 revert InsufficientBalance({
      available: balance[msg.sender],
      required: amount
  });
 */
error PriceMoreThanOneWei();
error FeeEqualToListingFee();
error IdLessOrEqualItemCount();
error ItemMustBeOnMarketplace();
error SubmitActualPrice();

contract Marketplace is ReentrancyGuard, Ownable {
    // * EXTERNAL LIBRARIES START >>>
    // Create 2 variables with Counters to increment or decrement them by 1
    using Counters for Counters.Counter;
    Counters.Counter private _itemCounter; // Start from 1 => Items created on the marketplace
    Counters.Counter private _itemSoldCounter; // => Items already solt in the marketplace

    // Just in case we need to do maths with our values/uint256 ...
    using SafeMath for uint256;

    // ? Can we implement this ?
    // There is a function some lines below that uses the address library to check if the address is a contract.
    using Address for address;
    // * EXTERNAL LIBRARIES END >>>

    // * Variables/Structs/Enums declaration START >>>
    // The market has an owner which is the contract deployer. Listing fee will be going to market owner when an NFT item is sold in the market.
    uint256 public listingFee = 0.025 ether;

    // ?  Variable to know who is the owner of the MarketItem ?
    address payable public marketOwner;

    // With enum we create an object with the 3 states for the marketItem
    enum MarketItemState {
        Listed,
        Release,
        Inactive
    }
    // We need to create a MarketItem strcture to store the data and play with it
    struct MarketItem {
        uint256 id; // id of the item
        address nftContract; // address of the NFT item
        uint256 tokenId; // ? What is this ?
        address payable seller; // Who sells the market item
        address payable buyer; // Who buys the market item
        uint256 price; // the price of the market item
        MarketItemState state; // The state
    }

    // Store all items (MaketItems) in a mapping
    mapping(uint256 => MarketItem) private marketItems;
    // * Variables/Structs/Enums declaration END >>>

    // * Events for the smart contract => Listening for events and updating user interface // Up to 3 parameters can be indexed.
    // indexed => Adds the paramater to a special data structure known as "topic". Topic can only hold a single word (32bytes)
    // Parameters without the indexed attribute are ABI-enconded into the data part of the log.
    // ! we can call an event with the "emit" keyword followed by the event name and the parameters.
    // ? Seems like we can access to this event from the FE ?
    event MarketItemListed(
        uint256 indexed id,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        MarketItemState state
    );

    event MarketItemSold(
        uint256 indexed id,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        MarketItemState state
    );

    // * Constructor
    // Solidity provides a constructor declaration inside the smart contract and it invokes only once when the contract is deployed and is used to initialize the contract state
    constructor() {
        marketOwner = payable(msg.sender);
    }

    // * function to check if the contract address is a wallet or an smart contract
    // ? I don't know if we need that and if it's the best way to use it here ?
    function checkIsContract(address _addr) public view returns (bool) {
        return _addr.isContract();
    }

    // * function that returns the listingFee
    function getListingFee() public view returns (uint256) {
        return listingFee;
    }

    // * CREATE A LISTING / NFT ITEM
    // * Create a MarketItem for NFT sale on the Marketplace => Listing
    // msg.value => Contains the amount of ETH that was sent in the transaction.
    // msg.sender => Contains the address of the person (or smart contract) who called the current function.
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        if (price < 0) {
            revert PriceMoreThanOneWei(); // Price must be greater than 1 wei
        }
        if (msg.value != price) {
            revert FeeEqualToListingFee(); // Fee must be equal to the listing fee
        }
        // require(price > 0, "Price must be greater than 1 wei");
        // require(
        //     msg.value == listingFee,
        //     "Fee must be equal to the listing fee"
        // );

        // When creating the marketItem, we increment the _itemCounter variable by 1 and also, we save that _itemCounter state value to the MarketItem id
        _itemCounter.increment();
        uint256 id = _itemCounter.current();

        // We add to the marketItems mapping the new MarketItem with the id as key (generated before).
        // It contains the data that we want to store for that MarketItem also, the address of the person who called the function and his address.
        marketItems[id] = MarketItem(
            id,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            MarketItemState.Listed
        );

        // * This require seems to be important - Don't know how to implement it.
        // * We can also pass it a custom error like before, and not using string for it.
        // ! Modify this require to match ERC1155 contract
        // require(IERC721(nftContract).getApproved(tokenId) == address(this), "NFT must be approved to market");

        // * Now that we have a MarketItem, we can emit an event with the data that we want to show in the FE?
        emit MarketItemListed(
            id,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            MarketItemState.Listed
        );
    }

    // * DELETE A LISTING
    // * Delete a MarketItem from the marketplace
    // ? There is a require statement to check if the owner is the same as the one who made the listing. I'm using the onlyOwner on this function but don't know if works like that.
    function deleteMarketItem(uint256 itemId) public onlyOwner nonReentrant {
        if (itemId >= _itemCounter.current()) {
            revert IdLessOrEqualItemCount();
        }
        if (marketItems[itemId].state != MarketItemState.Listed) {
            revert ItemMustBeOnMarketplace();
        }
        // require(
        //     itemId <= _itemCounter.current(),
        //     "id must be less or equal than item count"
        // );
        // require(
        //     marketItems[itemId].state == MarketItemState.Listed,
        //     "Item must be on the Marketplace"
        // );

        MarketItem storage item = marketItems[itemId];

        // ! Modify this require to match ERC1155 contract
        // * We can also add a custom error here
        // require(
        //     IERC721(item.nftContract).ownerOf(item.tokenId) == msg.sender,
        //     "must be the owner"
        // );
        // require(
        //     IERC721(item.nftContract).getApproved(item.tokenId) ==
        //         address(this),
        //     "NFT must be approved to market"
        // );

        item.state = MarketItemState.Inactive;

        emit MarketItemSold(
            itemId,
            item.nftContract,
            item.tokenId,
            item.seller,
            address(0),
            0,
            MarketItemState.Inactive
        );
    }

    // * BUY AN NFT ITEM
    // * Transfer ownership of the item to the buyer, as well as founds to the seller
    function createMarketSale(address nftContract, uint256 id)
        public
        payable
        nonReentrant
    {
        MarketItem storage item = marketItems[id];
        uint256 price = item.price;
        uint256 tokenId = item.tokenId;

        if (msg.value != price) {
            revert SubmitActualPrice();
        }
        // ! Modify this require to match ERC1155 contract
        // * We can also add a custom error here
        // require(IERC721(nftContract).getApproved(tokenId) == address(this), "NFT must be approved to market");

        item.buyer = payable(msg.sender);
        item.state = MarketItemState.Release;
        _itemSoldCounter.increment();

        // ! Modify this require to match ERC1155 contract
        // On ERC1155 there are mutiple functions to transfer like: safeTransferFrom
        /** Params/properties for the function
          - address from
          - address to
          - uint256 id
          - uint256 amount
          - bytes memory data
          */
        ERC1155(nftContract).safeTransferFrom(
            item.seller, // ? Are those correct?
            item.buyer, // ? Are those correct?
            tokenId, // ? Are those correct?
            price,
            bytes("") // ????
        );
        payable(marketOwner).transfer(listingFee);
        item.seller.transfer(msg.value);

        emit MarketItemSold(
            id,
            nftContract,
            tokenId,
            item.seller,
            msg.sender,
            price,
            MarketItemState.Release
        );
    }

    // TODO Query functions
    // function fetchActiveItems() public view returns (MarketItem[] memory) {}

    // function fetchMyPurchasedItems() public view returns (MarketItem[] memory) {}

    // function fetchMyCreatedItems() public view returns (MarketItem[] memory) {}
}
