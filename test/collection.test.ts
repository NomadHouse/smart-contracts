import { deployments, ethers } from "hardhat";
import { solidity } from "ethereum-waffle";

import {
  makeMarketplaceContract,
  getSigner,
  Signer,
  maybeAddressableToString,
  makeETHBalanceGetter,
  MaybeAddressable,
  makeCollectionContract,
  paddedBytes32,
} from "./util.test";

import { expect, config as ChaiConfig, use as ChaiUse } from "chai";
import ChaiAsPromised from "chai-as-promised";
import { BigNumber } from "ethers";

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
      ).to.eventually.be.rejectedWith(
        RegExp("ERC721: owner query for nonexistent token")
      );

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
        const titleId = paddedBytes32("0x248248248248");
        let requestId: string;

        beforeEach("verifyTitleOwnership", async () => {
          const collection = await makeCollectionContract(Signer.deployer);

          requestId = await collection.callStatic.verifyTitleOwnership(titleId);

          await collection.verifyTitleOwnership(titleId);
        });

        beforeEach("fulfillTitleOwnershipVerification", async () => {
          const oracle = await maybeAddressableToString(Signer.oracle);
          const collection = await makeCollectionContract(oracle);
          const owner = await maybeAddressableToString(Signer.seller);
          const fractionalization = 52;
          const verified = true;
          await collection.fulfillTitleOwnershipVerification(
            requestId,
            owner,
            fractionalization,
            verified
          );
        });

        it("title", async () => {
          const collection = await makeCollectionContract();
          const owner = await maybeAddressableToString(Signer.seller);

          const title = await collection.getTitle(titleId);
          expect(title).to.deep.equal([owner, 52, []]);
        });

        describe("mint one NFT", () => {
          const tokenId = 1;

          beforeEach("mint 1", async () => {
            const collection = await makeCollectionContract(Signer.seller);
            await collection.mintDeeds(titleId, 1);
          });

          it("title", async () => {
            const collection = await makeCollectionContract();
            const owner = await maybeAddressableToString(Signer.seller);

            const title = await collection.getTitle(titleId);
            expect(title.owner, "owner").to.equal(owner);
            expect(title.deedsLeftToMint_).to.equal(51);
            expect(title.deeds_.map(BigNumber.from)).to.deep.equal(
              [tokenId].map(BigNumber.from)
            );
          });

          it("uri", async () => {
            const collection = await makeCollectionContract();
            const uri = await collection.uri(tokenId);
            expect(uri).to.equal("https://fake.faux/1.json");
          });

          describe("mint 51 NFTs", () => {
            beforeEach("mint 51", async () => {
              const collection = await makeCollectionContract(Signer.seller);
              await collection.mintDeeds(titleId, 51);
            });

            it("title", async () => {
              const collection = await makeCollectionContract();
              const owner = await maybeAddressableToString(Signer.seller);

              const title = await collection.getTitle(titleId);
              expect(title.owner, "owner").to.equal(owner);
              expect(title.deedsLeftToMint_).to.equal(0);
              expect(title.deeds_.map(BigNumber.from)).to.deep.equal(
                range(1, 53).map(BigNumber.from) // [1,53) aka [1,52]
              );
            });
          });
        });
      });
    });
  });
});

function range(start: number, end: number): number[] {
  const array = [];
  for (let n = start; n < end; n++) {
    array.push(n);
  }
  return array;
}
