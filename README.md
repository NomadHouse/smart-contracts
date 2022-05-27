# smart-contracts

[![standard-readme compliant](https://img.shields.io/badge/standard--readme-OK-green.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
TODO: Put more badges here.

This package contains the smart contracts and related tooling.
This includes deployment code, past deployment info, and generated TypeScript wrappers. 

There are two smart contracts of note:
1. Collection. This is the NFT.
2. Marketplace. This is a simple custom contract for NFT trading.

## Table of Contents

- [Installation](#install)
- [Usage](#usage)
- [Smart Contracts](#smart contracts)
- [Maintainers](#maintainers)

# Dev Environment setup

## Install
Install the dependencies then create the generated code:
```
npm install
npm run build
```
    
## Test
```
npm run test
```
  
# Usage

## Deploy
```
PRIVATE_KEY=$deployerPrivateKey npm run deploy --network kovan
```

# Smart Contracts

## Collection (NFT)
The NFT contract deals with titles and deeds.
Deeds are NFTs.
Titles help manage permissions to mint Deeds.

Each title has to be verified for permission to mint deeds.
This process uses Chainlink to make an HTTP API call.

The owner of a verified title can mint the Deed NFTs.
This is doable in batches for gas cost reasons:
each title can have 1-52 deeds.
A future development will enable delayed minting.

### Creating NFTs
1. Call `Collection.verifyTitleOwnership`
2. Wait for `TitleVerified` or `TitleRejected` log.
   These are emitted when the Chainlink node calls `Collection.fullfillTitleOwnershipVerification`.
3. Call `Collection.mintDeeds` as many times as needed.
   The `howMany` parameter is adjustable to manage gas cost per transaction.

### Selling NFTs
1. Create NFT.
2. Call `Collection.setApprovalForAll(Marketplace.address, true)`.
3. Call `Marketplace.post`
   If you want to sell immediately, the `ready` argument should be `true`.

### Buying NFTs
1. Get KYC'd. Currently this is done only by the NFT owner via `authorizeWallet`.
2. Call `Marketplace.getListings` as many times as needed to find the NFT you want to buy.
3. Call `Marketplace.buy` with the `value` optional argument set to the posted `price`.
   The `listingId` is the array index of the posted listing for the NFT sale.

### Collecting Fees
1. Call `Marketplace.collectFees`.
   Most likely the `gasLimit` can be `21000`, as that's sufficient for an EOA.


## Marketplace
The marketplace is simple:
1. Post a NFT for sale
2. Buy that NFT

The KYC requirement is enforced in the NFT, not the Marketplace.

The fee is set at deployment.
A future development will make the fee changeable for new listings.

# Maintainers

[@FuzzB0t](https://github.com/FuzzB0t)
[@williamdanger](https://github.com/williamdanger)
[@paniaguaadrian](https://github.com/paniaguaadrian)
[@calebwursten](https://github.com/calebwursten)
[@felzix](https://github.com/felzix)
