import { deployments } from "hardhat";
import { solidity } from "ethereum-waffle";

import {
  BASIS,
  ListingState,
  makeMarketplaceContract,
  makeNFTContract,
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
} from "./util.test";
import { FEE_PERCENT } from "../deploy/002_marketplace/000_deploy_marketplace";

import { expect, config as ChaiConfig, use as ChaiUse } from "chai";
import ChaiAsPromised from "chai-as-promised";
import { BigNumber } from "ethers";

ChaiUse(ChaiAsPromised);
ChaiUse(solidity);

describe("Marketplace", function () {
  ChaiConfig.includeStack = true;
  ChaiConfig.showDiff = true;

  beforeEach(() => deployments.fixture());

  let getETHBalance: (who: MaybeAddressable) => Promise<BigNumber>;
  beforeEach(async () => {
    getETHBalance = makeETHBalanceGetter(await getSigner(0));
  });

  describe("unspoiled marketplace", () => {
    it("marketplace deploys correctly", async () => {
      const marketplace = await makeMarketplaceContract();
      const nftContract = await makeNFTContract();
      const deployer = await maybeAddressableToString(Signer.deployer);

      const owner = await marketplace.owner();
      const nft = await marketplace.nft();
      const feePercent = await marketplace.feePercent();
      const collectableFees = await marketplace.collectableFees();

      expect(owner, "owner").to.equal(deployer);
      expect(nft, "nft").to.equal(nftContract.address);
      expect(feePercent, "feePercent").to.equal(FEE_PERCENT);
      expect(collectableFees, "feePercent").to.equal(0);
    });

    it("fake 0th listing exists", async () => {
      await assertListing({
        listingId: 0,
        seller: NULL_ADDRESS,
        tokenId: 0,
        price: 0,
        state: ListingState.None,
      });
    });

    it("try to collect no fees", async () => {
      const marketplace = await makeMarketplaceContract();
      await expect(marketplace.collectFees(21000)).to.eventually.be.fulfilled;
    });

    describe("acquire an NFT", () => {
      const tokenId = BigNumber.from(42);

      beforeEach("mint fake NFT", async () => {
        const nft = await makeNFTContract(Signer.seller);
        await nft.faucet(tokenId, 1);
      });

      describe("approve marketplace", () => {
        beforeEach("approve marketplace to spend NFTs", async () => {
          const marketplace = await makeMarketplaceContract();
          const nft = await makeNFTContract(Signer.seller);
          await nft.setApprovalForAll(marketplace.address, true);
        });

        describe("post a listing", () => {
          const price = BASIS; // 1 eth
          const fee = price.mul(FEE_PERCENT).div(100);
          const afterFee = price.sub(fee);
          const listingId = 1;

          beforeEach("postListing", async () => {
            await postListing({ seller: Signer.seller, tokenId, price });
          });

          it("listing posted", async () => {
            await assertListing({
              listingId,
              tokenId,
              seller: Signer.seller,
              price,
              state: ListingState.Active,
            });
          });

          describe("buy NFT", () => {
            beforeEach("buy", async () => {
              await buyListing({ buyer: Signer.buyer, listingId, price });
            });

            it("listing sold", async () => {
              await assertListing({
                listingId,
                state: ListingState.Sold,
              });
            });

            it("marketplace has ETH", async () => {
              const marketplace = await makeMarketplaceContract();
              const balance = await getETHBalance(marketplace);
              expect(balance).to.equal(price);
            });

            describe("collect earnings", () => {
              let sellerETHBeforeSale: BigNumber;
              beforeEach("get ETH before sale", async () => {
                sellerETHBeforeSale = await getETHBalance(Signer.seller);
              });

              beforeEach("collect", async () => {
                await collectEarnings({ seller: Signer.seller, listingId });
              });

              it("listing closed", async () => {
                await assertListing({
                  listingId,
                  state: ListingState.Closed,
                });
              });

              it("seller got their ETH", async () => {
                // Since expect.approximately works with numbers not BigNumber,
                // doing some division to make that work.
                // This should be fine because math:
                // 1e(8+6) = 1e14, which is well below `afterFee` at 0.8e18
                const divisorForOverflow = 1e8;
                const leewayForGasCost = 1e6;

                const balance = (await getETHBalance(Signer.seller))
                  .div(divisorForOverflow)
                  .toNumber();
                const expected = sellerETHBeforeSale
                  .add(afterFee)
                  .div(divisorForOverflow)
                  .toNumber();
                expect(balance).to.approximately(expected, leewayForGasCost);
              });

              it("marketplace still has fee", async () => {
                const marketplace = await makeMarketplaceContract();
                const balance = await getETHBalance(marketplace);
                expect(balance).to.equal(fee);
              });

              it("cannot collect twice", async () => {
                await expect(
                  collectEarnings({ seller: Signer.seller, listingId })
                ).to.eventually.be.rejectedWith(RegExp("listing not Sold"));
              });

              describe("collect fees", () => {
                let deployerETHBeforeSale: BigNumber;
                beforeEach("get ETH before sale", async () => {
                  deployerETHBeforeSale = await getETHBalance(Signer.deployer);
                });

                beforeEach("collect", async () => {
                  await collectFees({ owner: Signer.deployer });
                });

                it("marketplace has no ETH", async () => {
                  const marketplace = await makeMarketplaceContract();
                  const balance = await getETHBalance(marketplace);
                  expect(balance).to.equal(0);
                });

                it("owner got their ETH", async () => {
                  // Since expect.approximately works with numbers not BigNumber,
                  // doing some division to make that work.
                  // This should be fine because math:
                  // 1e(8+6) = 1e14, which is well below `fee` at 0.2e18
                  const divisorForOverflow = 1e8;
                  const leewayForGasCost = 1e6;

                  const balance = (await getETHBalance(Signer.deployer))
                    .div(divisorForOverflow)
                    .toNumber();
                  const expected = deployerETHBeforeSale
                    .add(fee)
                    .div(divisorForOverflow)
                    .toNumber();
                  expect(balance).to.approximately(expected, leewayForGasCost);
                });
              });
            });

            describe("collect fees", () => {
              let deployerETHBeforeSale: BigNumber;
              beforeEach("get ETH before sale", async () => {
                deployerETHBeforeSale = await getETHBalance(Signer.deployer);
              });

              beforeEach("collect", async () => {
                await collectFees({ owner: Signer.deployer });
              });

              it("marketplace has earnings ETH still", async () => {
                const marketplace = await makeMarketplaceContract();
                const balance = await getETHBalance(marketplace);
                expect(balance).to.equal(afterFee);
              });

              it("owner got their ETH", async () => {
                // Since expect.approximately works with numbers not BigNumber,
                // doing some division to make that work.
                // This should be fine because math:
                // 1e(8+6) = 1e14, which is well below `fee` at 0.2e18
                const divisorForOverflow = 1e8;
                const leewayForGasCost = 1e6;

                const balance = (await getETHBalance(Signer.deployer))
                  .div(divisorForOverflow)
                  .toNumber();
                const expected = deployerETHBeforeSale
                  .add(fee)
                  .div(divisorForOverflow)
                  .toNumber();
                expect(balance).to.approximately(expected, leewayForGasCost);
              });
            });
          });

          describe("pause listing", () => {
            beforeEach("pause", async () => {
              await pauseListing({ seller: Signer.seller, listingId });
            });

            it("listing paused", async () => {
              await assertListing({
                listingId,
                state: ListingState.Paused,
              });
            });

            describe("unpause listing", () => {
              beforeEach("pause", async () => {
                await unPauseListing({ seller: Signer.seller, listingId });
              });

              it("listing active", async () => {
                await assertListing({
                  listingId,
                  state: ListingState.Active,
                });
              });

              describe("cancel listing", () => {
                beforeEach("cancel", async () => {
                  await cancelListing({ seller: Signer.seller, listingId });
                });

                it("listing cancelled", async () => {
                  await assertListing({
                    listingId,
                    state: ListingState.Cancelled,
                  });
                });
              });
            });
            describe("cancel listing", () => {
              beforeEach("cancel", async () => {
                await cancelListing({ seller: Signer.seller, listingId });
              });

              it("listing cancelled", async () => {
                await assertListing({
                  listingId,
                  state: ListingState.Cancelled,
                });
              });

              it("cannot change listing state", async () => {
                await expect(
                  unPauseListing({ seller: Signer.seller, listingId }),
                  "unPause"
                ).to.eventually.be.rejected;
                await expect(
                  pauseListing({ seller: Signer.seller, listingId }),
                  "pause"
                ).to.eventually.be.rejected;
                await expect(
                  cancelListing({ seller: Signer.seller, listingId }),
                  "cancel"
                ).to.eventually.be.rejected;
              });

              it("cannot buy listing", async () => {
                await expect(
                  buyListing({ buyer: Signer.buyer, listingId, price })
                ).to.eventually.be.rejectedWith(RegExp("listing not active"));
              });
            });
          });
        });
      });
    });
  });
});
