import { deployments } from "hardhat";
import { solidity } from "ethereum-waffle";

import {
  BASIS,
  ListingState,
  makeMarketplaceContract,
  makeTestNFTContract,
  NULL_ADDRESS,
  pauseListing,
  postListing,
  getSigner,
  Signer,
  assertListing,
  maybeAddressableToString,
  unPauseListing,
  cancelListing,
  buyListing,
  collectEarnings,
  collectFees,
  makeETHBalanceGetter,
  MaybeAddressable,
  makeCollectionContract,
} from "./util.test";
import { FEE_PERCENT } from "../deploy/002_marketplace/000_deploy_marketplace";

import { expect, config as ChaiConfig, use as ChaiUse } from "chai";
import ChaiAsPromised from "chai-as-promised";
import { BigNumber } from "ethers";
import { arrayify, hexlify } from "ethers/lib/utils";

ChaiUse(ChaiAsPromised);
ChaiUse(solidity);

describe("Collection", function () {
  ChaiConfig.includeStack = true;
  ChaiConfig.showDiff = true;

  beforeEach(() => deployments.fixture());

  let getETHBalance: (who: MaybeAddressable) => Promise<BigNumber>;
  beforeEach(async () => {
    getETHBalance = makeETHBalanceGetter(await getSigner(0));
  });

  describe("default", () => {
    it("collection deploys correctly", async () => {
      const collection = await makeCollectionContract();
      const deployer = await maybeAddressableToString(Signer.deployer);

      const name = await collection.name();
      const symbol = await collection.symbol();
      const owner = await collection.owner();

      const paused = await collection.paused();

      expect(name).to.equal("NomadHouse");
      expect(symbol).to.equal("NMH");
      expect(owner).to.equal(deployer);
      expect(paused).to.be.true;
    });

    it("fake deed does not exist", async () => {
      const collection = await makeCollectionContract();
      const FAKE_DEED_ID = 0;

      await expect(
        collection.ownerOf(FAKE_DEED_ID),
        "ownerOf"
      ).to.eventually.be.rejectedWith(RegExp("Deed does not exist"));

      await expect(
        collection.uri(FAKE_DEED_ID),
        "uri"
      ).to.eventually.be.rejectedWith(RegExp("Deed does not exist"));

      const exists = await collection.exists(FAKE_DEED_ID);
      expect(exists, "exists").to.be.false;
    });
  });

  describe("set up collection", () => {
    const tokenURI = "https://fake.faux/";
    const titleSearchURI = "https://false.faux/";

    beforeEach("setTokenURI", async () => {
      const collection = await makeCollectionContract(Signer.deployer);
      await collection.setTokenURI(tokenURI);
    });

    beforeEach("setTitleSearchURI", async () => {
      const collection = await makeCollectionContract(Signer.deployer);
      await collection.setTitleSearchURI(titleSearchURI);
    });

    beforeEach("setMarketplaceContract", async () => {
      const collection = await makeCollectionContract(Signer.deployer);
      const marketplace = await makeMarketplaceContract();
      await collection.setMarketplaceContract(marketplace.address);
    });
    beforeEach("unpause", async () => {
      const collection = await makeCollectionContract(Signer.deployer);
      await collection.unpause();
    });

    it("verify setup", async () => {
      const collection = await makeCollectionContract(Signer.deployer);
      const paused = await collection.paused();
      expect(paused, "paused").to.be.false;
    });

    describe("authorize intended owner", () => {
      const intendedOwner = Signer.seller;
      beforeEach("authorizeWallet", async () => {
        const collection = await makeCollectionContract(Signer.deployer);
        const address = await maybeAddressableToString(intendedOwner);
        await collection.authorizeWallet(address);
      });

      describe("verify title ownership", () => {
        const titleId = arrayify(1234);
        beforeEach("verifyTitleOwnership", async () => {
          const collection = await makeCollectionContract(Signer.deployer);
          await collection.verifyTitleOwnership(titleId);
        });
      });
    });
  });
});
