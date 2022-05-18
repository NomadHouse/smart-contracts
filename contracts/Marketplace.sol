// contracts/Marketplace.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Marketplace is Ownable, ReentrancyGuard {
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
        uint256 price, // ETH (denominated in WEI)
        bool ready // true -> immediately available for sale; false -> must be unPause'd
    ) public {
        // NOTE: This does *NOT* guarantee the NFT is approved later.
        //       We only check here to prevent accidents, not malice.
        require(
            nft.isApprovedForAll(msg.sender, address(this)),
            "approve NFT contract"
        );
        // NOTE: This does *NOT* guarantee the NFT is owned by this account later.
        //       We only check here to prevent accidents, not malice.
        require(
            nft.balanceOf(msg.sender, tokenId) == 1,
            "only NFT owner may post"
        );

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

    function cancel(uint256 listingId) public {
        Listing storage listing = listings[listingId];

        require(listing.seller == msg.sender, "must be seller");
        require(
            listing.state == ListingState.Active ||
                listing.state == ListingState.Paused,
            "listing not Active or Paused"
        );

        listing.state = ListingState.Cancelled;

        emit ListingChange(listingId, listing.state);
    }

    // NOTE: Can fail if the seller is no longer the owner
    //       or if the Marketplace is no longer approved.
    function buy(uint256 listingId) public payable nonReentrant {
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

    function collect(uint256 listingId, uint256 gasLimit) public {
        Listing storage listing = listings[listingId];

        require(listing.seller == msg.sender, "must be seller");
        require(listing.state == ListingState.Sold, "listing not Sold");

        uint256 owed = (listing.price * 100) / (100 - feePercent);

        (bool sent, ) = listing.seller.call{value: owed, gas: gasLimit}("");
        require(sent, "failed to collect listing sales");
    }

    function collectFees(uint256 gasLimit) public onlyOwner {
        uint256 owed = collectableFees;
        collectableFees = 0;

        (bool sent, ) = owner().call{value: owed, gas: gasLimit}("");
        require(sent, "failed to send fees");
    }
}
