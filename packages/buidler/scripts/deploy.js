const fs = require('fs')
const chalk = require('chalk')
const { config, ethers } = require('@nomiclabs/buidler')
const { utils } = ethers
const n = require('eth-ens-namehash')
const namehash = n.hash

const addresses = {}

async function deploy(name, _args) {
  const args = _args || []

  console.log(`📄 ${name}`)
  const contractArtifacts = await ethers.getContractFactory(name)
  const contract = await contractArtifacts.deploy(...args)
  console.log(chalk.cyan(name), 'deployed to:', chalk.magenta(contract.address))
  fs.writeFileSync(`artifacts/${name}.address`, contract.address)
  console.log('\n')
  contract.name = name
  addresses[name] = contract.address
  return contract
}

const isSolidity = (fileName) =>
  fileName.indexOf('.sol') >= 0 && fileName.indexOf('.swp.') < 0

function readArgumentsFile(contractName) {
  let args = []
  try {
    const argsFile = `./contracts/${contractName}.args`
    if (fs.existsSync(argsFile)) {
      args = JSON.parse(fs.readFileSync(argsFile))
    }
  } catch (e) {
    console.log(e)
  }

  return args
}

const NO_AUTO_DEPLOY = [
  'PublicResolver.sol',
  'SubdomainRegistrar.sol',
  'RestrictedNameWrapper.sol',
]

async function autoDeploy() {
  const contractList = fs.readdirSync(config.paths.sources)
  return contractList
    .filter((fileName) => {
      if (NO_AUTO_DEPLOY.includes(fileName)) {
        //don't auto deploy this list of Solidity files
        return false
      }
      return isSolidity(fileName)
    })
    .reduce((lastDeployment, fileName) => {
      const contractName = fileName.replace('.sol', '')
      const args = readArgumentsFile(contractName)

      // Wait for last deployment to complete before starting the next
      return lastDeployment.then((resultArrSoFar) =>
        deploy(contractName, args).then((result) => [...resultArrSoFar, result])
      )
    }, Promise.resolve([]))
}

async function main() {
  console.log('📡 Deploy \n')
  // auto deploy to read contract directory and deploy them all (add ".args" files for arguments)
  const contractList = await autoDeploy()
  console.log('finish auto deploy')

  //console.log('contractList', contractList)
  const EnsRegistry = contractList.find(
    (contract) => contract.name === 'ENSRegistry'
  )
  const ROOT_NODE =
    '0x0000000000000000000000000000000000000000000000000000000000000000'

  const rootOwner = await EnsRegistry.owner(ROOT_NODE)
  const [owner, addr1] = await ethers.getSigners()
  const account = await owner.getAddress()

  const SubDomainRegistrar = await deploy('SubdomainRegistrar', [
    addresses['ENSRegistry'],
  ])
  const RestrictedNameWrapper = await deploy('RestrictedNameWrapper', [
    addresses['ENSRegistry'],
  ])
  const PublicResolver = await deploy('PublicResolver', [
    addresses['ENSRegistry'],
  ])

  // setup .eth
  await EnsRegistry.setSubnodeOwner(
    ROOT_NODE,
    utils.keccak256(utils.toUtf8Bytes('eth')),
    account
  )

  // setup ens.eth
  await EnsRegistry.setSubnodeOwner(
    namehash('eth'),
    utils.keccak256(utils.toUtf8Bytes('ens')),
    account
  )

  const ethOwner = await EnsRegistry.owner(namehash('eth'))
  const ensEthOwner = await EnsRegistry.owner(namehash('ens.eth'))

  console.log('ethOwner', ethOwner)
  console.log('ensEthOwner', ensEthOwner)
  // OR
  // custom deploy (to use deployed addresses dynamically for example:)
  // const exampleToken = await deploy("ExampleToken")
  // const examplePriceOracle = await deploy("ExamplePriceOracle")
  // const smartContractWallet = await deploy("SmartContractWallet",[exampleToken.address,examplePriceOracle.address])

  // setup subdomain registrar
  //console.log(subDomainRegistrar)
  await SubDomainRegistrar.configureDomain('ens', '1000000', 0)
  await EnsRegistry.setOwner(namehash('ens.eth'), SubDomainRegistrar.address)
  await SubDomainRegistrar.register(
    '0x5cee339e13375638553bdf5a6e36ba80fb9f6a4f0783680884d92b558aa471da',
    'awesome',
    account,
    account,
    addresses['PublicResolver'],
    {
      value: '1000000',
    }
  )

  // await subDomainRegistrar.register(
  //   '0x5cee339e13375638553bdf5a6e36ba80fb9f6a4f0783680884d92b558aa471da',
  //   'awesome',
  //   account,
  //   account,
  //   addresses['PublicResolver'],
  //   {
  //     value: '100000',
  //   }
  // )

  console.log('configured ens.eth in subdomain Registrar')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
