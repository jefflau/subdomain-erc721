const { ethers } = require('@nomiclabs/buidler')
const { use, expect } = require('chai')
const { solidity } = require('ethereum-waffle')

use(solidity)

describe('My Dapp', function () {
  let MultiSigContract
  let TestContract

  describe('YourContract', function () {
    it('Should deploy YourContract', async function () {
      const MultiSig = await ethers.getContractFactory('MultiSig')
      const Test = await ethers.getContractFactory('Test')

      const accounts = await ethers.getSigners()

      MultiSigContract = await MultiSig.deploy([accounts[0]], 1)
      TestContract = await Test.deploy()
    })

    describe('setPurpose()', function () {
      it('Should be able to submit a new tx', async function () {
        const callData = await TestContract.getData()

        await MultiSigContract.submitTransaction(TestContract.address, callData)
      })
    })
  })
})
