// Load dependencies
const { expect, assert } = require('chai');
const truffleAssert = require('truffle-assertions');
require('dotenv').config()

/* eslint-disable @typescript-eslint/no-var-requires */
const { oracle } = require('@chainlink/test-helpers')
const { expectRevert, time, balance } = require('@openzeppelin/test-helpers')

// Load utilities 
var BN = web3.utils.BN;

describe("Collection contract", function () {
  
  const { LinkToken } = require('../truffle/v0.4/LinkToken')
  const { Oracle } = require('../truffle/v0.6/Oracle')
  const Collection = artifacts.require('Collection');

  const defaultAccount = accounts[0]
  const oracleNode = accounts[1]
  const stranger = accounts[2]
  const consumer = accounts[3]

  // These parameters are used to validate the data was received
  // on the deployed oracle contract. The Job ID only represents
  // the type of data, but will not work on a public testnet.
  // For the latest JobIDs, visit a node listing service like:
  // https://market.link/
  const jobId = web3.utils.toHex('4c7b7ffb66b344fbaa64995af81e355a')
  const url =
    'https://bafybeihuftdtf5rjkep52k5afrydtlo4mvznafhtmrsqaunaninykew3qe.ipfs.dweb.link/'
  const titleId = 'test-title.json'

  // Represents 1 LINK for testnet requests
  const payment = web3.utils.toWei('1')

  let link, oc, cc

  
  // build up and tear down a new Collection contract before each test
  beforeEach(async () => {
    link = await LinkToken.new({ from: defaultAccount })
    oc = await Oracle.new(link.address, { from: defaultAccount })
    cc = await Collection.new(link.address, { from: defaultAccount })
    await oc.setFulfillmentPermission(oracleNode, true, {
      from: defaultAccount,
    })
  });

  describe('#createRequest', () => {
    context('without LINK', () => {
      it('reverts', async () => {
        await expectRevert.unspecified(
          cc.verifyTitleOwnership(oc.address, jobId, payment, url, path, times, {
            from: consumer,
          }),
        )
      })
    })

    context('with LINK', () => {
      let request

      beforeEach(async () => {
        await link.transfer(cc.address, web3.utils.toWei('1', 'ether'), {
          from: defaultAccount,
        })
      })

      context('sending a request to our oracle contract address', () => {
        it('triggers a log event in the new Oracle contract', async () => {
          const tx = await cc.verifyTitleOwnership(
            titleId,
            { from: consumer },
          )
          request = oracle.decodeRunRequest(tx.receipt.rawLogs[3])
          assert.equal(oc.address, tx.receipt.rawLogs[3].address)
          assert.equal(
            request.topic,
            web3.utils.keccak256(
              'OracleRequest(bytes32,address,bytes32,uint256,address,bytes4,uint256,uint256,bytes)',
            ),
          )
        })
      })
    })
  })

  describe('#fulfill - verifyTitleOwnership', () => {
    const expected = 50000
    const response = web3.utils.padLeft(web3.utils.toHex(expected), 64)
    let request

    beforeEach(async () => {
      await link.transfer(cc.address, web3.utils.toWei('1', 'ether'), {
        from: defaultAccount,
      })
      const tx = await cc.verifyTitleOwnership(
        titleId,
        { from: consumer },
      )
      request = oracle.decodeRunRequest(tx.receipt.rawLogs[3])
      await oc.fulfill(
        ...oracle.convertFufillParams(request, response, {
          from: oracleNode,
          gas: 500000,
        }),
      )
    });

    it('records the data given to it by the oracle', async () => {
      const currentPrice = await cc.data.call()
      assert.equal(
        web3.utils.padLeft(web3.utils.toHex(currentPrice), 64),
        web3.utils.padLeft(expected, 64),
      )
    });
  });

  it('Can mint', async function () { 
    
  });

  it('Can batch mint', async function () { 
    
  });

});