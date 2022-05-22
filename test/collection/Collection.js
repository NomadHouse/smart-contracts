// Load dependencies
const { expect, assert } = require('chai');
require('dotenv').config()

/* eslint-disable @typescript-eslint/no-var-requires */
const { expectRevert, time, balance } = require('@openzeppelin/test-helpers')

// Load utilities 
var BN = web3.utils.BN;

describe("Collection contract", function () {
  const Collection = artifacts.require('Collection');

  const defaultAccount = accounts[0]

  let collection;

  // Build up and tear down a new Collection contract before each test
  beforeEach(async () => {
     collection = await Collection.new({ from: defaultAccount })
  });

});