import { ethers } from "hardhat";
import { BigNumber, BigNumberish } from "ethers";
import { expect } from "chai";

import { Collection, Marketplace, TestNFT } from "../typechain-types";
import { SignerWithAddress } from "hardhat-deploy-ethers/signers";
import { arrayify } from "ethers/lib/utils";

export const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
export const BASIS = BigNumber.from(10).pow(18); // 1e18 wei == 1 eth
export const DEFAULT_COLLECT_GAS_LIMTI = 2300;

export function makeETHBalanceGetter(signer: SignerWithAddress) {
  const provider = signer.provider;
  if (!provider) throw Error("signer must have provider");
  return async function (who: MaybeAddressable) {
    return provider.getBalance(await maybeAddressableToString(who));
  };
}

export enum ListingState {
  None = 0,
  Paused,
  Active,
  Sold,
  Closed,
  Cancelled,
}

export async function makeMarketplaceContract(
  signer?: MaybeAddressable
): Promise<Marketplace> {
  const address = signer ? await maybeAddressableToString(signer) : undefined;
  return (await ethers.getContract("Marketplace", address)) as Marketplace;
}

export async function postListing(opts: {
  seller: MaybeAddressable;
  tokenId: BigNumberish;
  price: BigNumberish;
  startsActive?: boolean;
}) {
  const startsActive =
    opts.startsActive === undefined ? true : opts.startsActive;
  const marketplace = await makeMarketplaceContract(opts.seller);
  await marketplace.post(opts.tokenId, opts.price, startsActive);
}

export async function buyListing(opts: {
  buyer: MaybeAddressable;
  listingId: BigNumberish;
  price: BigNumberish;
}) {
  const marketplace = await makeMarketplaceContract(opts.buyer);
  await marketplace.buy(opts.listingId, { value: opts.price });
}

export async function pauseListing(opts: {
  seller: MaybeAddressable;
  listingId: BigNumberish;
}) {
  const marketplace = await makeMarketplaceContract(opts.seller);
  await marketplace.pause(opts.listingId);
}

export async function unPauseListing(opts: {
  seller: MaybeAddressable;
  listingId: BigNumberish;
}) {
  const marketplace = await makeMarketplaceContract(opts.seller);
  await marketplace.unPause(opts.listingId);
}

export async function cancelListing(opts: {
  seller: MaybeAddressable;
  listingId: BigNumberish;
}) {
  const marketplace = await makeMarketplaceContract(opts.seller);
  await marketplace.cancel(opts.listingId);
}

export async function collectEarnings(opts: {
  seller: MaybeAddressable;
  listingId: BigNumberish;
  gasLimit?: BigNumberish;
}) {
  const gasLimit =
    opts.gasLimit === undefined ? DEFAULT_COLLECT_GAS_LIMTI : opts.gasLimit;
  const marketplace = await makeMarketplaceContract(opts.seller);
  await marketplace.collect(opts.listingId, gasLimit);
}

export async function collectFees(opts: { owner: MaybeAddressable }) {
  const marketplace = await makeMarketplaceContract(opts.owner);
  await marketplace.collectFees(DEFAULT_COLLECT_GAS_LIMTI);
}
export async function makeTestNFTContract(
  signer?: MaybeAddressable
): Promise<TestNFT> {
  const address = signer ? await maybeAddressableToString(signer) : undefined;
  return (await ethers.getContract("TestNFT", address)) as TestNFT;
}

export async function makeCollectionContract(
  signer?: MaybeAddressable
): Promise<Collection> {
  const address = signer ? await maybeAddressableToString(signer) : undefined;
  return (await ethers.getContract("NFT", address)) as Collection;
}

export async function assertListing(opts: {
  listingId: BigNumberish;
  seller?: MaybeAddressable;
  tokenId?: BigNumberish;
  price?: BigNumberish;
  state?: ListingState;
}) {
  const seller =
    opts.seller === undefined
      ? undefined
      : await maybeAddressableToString(opts.seller);
  const tokenId =
    opts.tokenId === undefined ? undefined : BigNumber.from(opts.tokenId);
  const price =
    opts.price === undefined ? undefined : BigNumber.from(opts.price);
  const marketplace = await makeMarketplaceContract();

  const listings = await marketplace.getListings(opts.listingId, 1);
  expect(listings.length).to.equal(1);

  const listing = listings[0];
  if (seller !== undefined) expect(listing.seller, "seller").to.equal(seller);
  if (tokenId !== undefined)
    expect(listing.tokenId, "tokenId").to.equal(tokenId);
  if (price !== undefined) expect(listing.price, "price").to.equal(price);
  if (opts.state !== undefined)
    expect(listing.state, "state").to.equal(opts.state);
}

type RawListing = [BigNumber, string, BigNumber, number];
interface Listing {
  tokenId: BigNumber;
  seller: string;
  price: BigNumber;
  state: number;
}
export function listingFromRaw(raw: RawListing): Listing {
  return {
    tokenId: BigNumber.from(raw[0]),
    seller: raw[1],
    price: BigNumber.from(raw[2]),
    state: raw[3],
  };
}

export enum Signer {
  deployer = 0,
  seller,
  buyer,
  oracle,
}

export function getSigner(id: Signer | string): Promise<SignerWithAddress> {
  if (typeof id === "string") {
    return ethers.getNamedSigner(id);
  } else {
    return ethers.getSigners().then((signers) => signers[id]);
  }
}

export type MaybeAddressable = string | number | Addressable;

export async function maybeAddressableToString(
  account: MaybeAddressable
): Promise<string> {
  if (isAddressable(account)) {
    return account.address;
  } else if (typeof account === "string") {
    return account;
  } else {
    return (await getSigner(account)).address;
  }
}

export interface Addressable {
  address: string;
}

export function isAddressable(x: any): x is Addressable {
  return (
    typeof x === "object" &&
    x !== null &&
    typeof (x as Addressable).address === "string"
  );
}

export function paddedBytes32(x: string): Uint8Array {
  while (x.length < 2 + 64) {
    x += "0";
  }
  return arrayify(x);
}
