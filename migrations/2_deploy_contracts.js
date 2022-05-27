const Collection = artifacts.require("Collection");
const Marketplace = artifacts.require("Marketplace");

const titleSearchUri =
    "https://bafybeihuftdtf5rjkep52k5afrydtlo4mvznafhtmrsqaunaninykew3qe.ipfs.dweb.link/";
const fee = 0;

// const oracle = "0x90F79bf6EB2c4f870365E785982E1f101E93b906"; // FAKE
const oracle = "0x094C858cF9428a4c18023AA714d3e205b6Db6354"; // KOVAN Address
// const { address: linkToken } = await deployments.get("TestLinkToken");
const linkToken = "0xa36085F69e2889c224210F603D836748e7dC0088"; // KOVAN Address

module.exports = function (deployer) {
  deployer.deploy(Collection, oracle, linkToken, titleSearchUri, fee);
  deployer.deploy(Marketplace, Collection.address, 2);
};