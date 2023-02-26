require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers")
require("dotenv").config();


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  networks: {
    hardhat : {

    },
    /*
    goerli : {
      url: `${process.env.GOERLI_URL}`,
      accounts: [process.env.PRIVATE_KEY],
      blockGasLimit: 20000000,
      gasPrice: 55000000000 // 35 Gwei
    },
    polygon : {
      url: `${process.env.POLYGON_URL}`,
      accounts: [process.env.PRIVATE_KEY],
      blockGasLimit: 20000000,
      gasPrice: 55000000000 // 35 Gwei
    },*/
  },
  mocha: {
    timeout: 1000000000000000000,
  },
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_API_KEY,
      // polygon: process.env.POLYGONSCAN_API_KEY
    },
  },
};