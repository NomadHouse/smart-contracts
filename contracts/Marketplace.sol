// contracts/Marketplace.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketPlace is Ownable, ReentrancyGuard {
    IERC1155 nft;
    uint256 feePercent;
    uint256 collectableFees;

    // The Listing identifier is its array index.
    Listing[] internal listings;

    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price; // ETH (denominated in WEI)
        ListingState state;
    }

    enum ListingState {
        None, // Listing does not exist.
        Paused, // Listing cannot be traded now but could be later.
        Active, // Listing is tradable now.
        // Finalizing, // Listing was traded, pending other step(s).
        Sold, // Listing was sold but the seller has no collected the payment.
        Closed, // Listing was traded and seller collected the payment.
        Cancelled // Listing was ended before being traded.
    }

    event NewListing(
        uint256 listingId,
        uint256 tokenId,
        address seller,
        uint256 price,
        ListingState state
    );
    event ListingChange(uint256 listingId, ListingState state);

    constructor(IERC1155 nft_, uint256 feePercent_) {
        nft = nft_;
        feePercent = feePercent_;
        // The 0th index is reserved to indicate the absence of a Listing identifier.
        listings.push(Listing(0, address(0), 0, ListingState.None));
    }

    function post(
        uint256 tokenId,
        uint256 price,
        bool ready
    ) public {
        // TODO: verify that token is owned or approved by msg.sender
        // TODO: verify that msg.sender has approved this contract

        ListingState state = ListingState.Paused;
        if (ready) {
            state = ListingState.Active;
        }
        listings.push(Listing(tokenId, msg.sender, price, state));

        emit NewListing(listings.length, tokenId, msg.sender, price, state);
    }

    function pause(uint256 listingId) public {
        Listing storage listing = listings[listingId];

        require(listing.seller == msg.sender, "must be seller");
        require(listing.state == ListingState.Active, "listing not Active");

        listing.state = ListingState.Paused;

        emit ListingChange(listingId, listing.state);
    }

    function unPause(uint256 listingId) public {
        Listing storage listing = listings[listingId];

        require(listing.seller == msg.sender, "must be seller");
        require(listing.state == ListingState.Paused, "listing not Paused");

        listing.state = ListingState.Active;

        emit ListingChange(listingId, listing.state);
    }

    function buy(uint256 listingId) public payable nonReentrant {
        // TODO: does altering `listing` here alters `listings[listingId]`?
        Listing storage listing = listings[listingId];

        require(listing.state == ListingState.Active, "listing not active");
        require(msg.value == listing.price, "wrong payment amount");

        listing.state = ListingState.Sold;

        nft.safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId,
            1,
            ""
        );

        uint256 fee = (msg.value * 100) / feePercent;
        collectableFees += fee;

        emit ListingChange(listingId, listing.state);
    }

    function collect(
        uint256 listingId,
        uint256 amount,
        uint256 gasLimit
    ) public {
        Listing storage listing = listings[listingId];

        require(msg.sender == listing.seller, "must be seller");
        require(listing.state == ListingState.Sold, "listing not Sold");

        (bool sent, ) = listing.seller.call{value: amount, gas: gasLimit}("");
        require(sent, "failed to collect listing sales");
    }

    function collectFees(uint256 amount, uint256 gasLimit) public onlyOwner {
        require(amount <= collectableFees, "insufficient fees");
        collectableFees -= amount;

        (bool sent, ) = owner().call{value: amount, gas: gasLimit}("");
        require(sent, "failed to send fees");
    }
}
