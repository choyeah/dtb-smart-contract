import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.13",
      },
      {
        version: "0.8.0",
      },
      {
        version: "0.5.6",
      },
      {
        version: "0.4.24",
      },
    ],
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
  },
  defaultNetwork: "localhost",
  networks: {
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20e9,
      gas: 25e6,
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20e9,
      gas: 25e6,
    },
    localhost: {
      url: "http://127.0.0.1:8545/",
      gasPrice: 20e9,
      gas: 25e6,
    },
    mumbai: {
      url: "https://polygon-mumbai.infura.io/v3/7618ab0b33ec40548070f4b40444e04f",
      chainId: 80001,
      gasPrice: 20e9,
      gas: 25e6,
      accounts: [""],
    },
    polygon: {
      url: "https://polygon-rpc.com",
      chainId: 137,
      accounts: [""],
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org",
      chainId: 56,
      accounts: [""],
    },
    bsc_testnet: {
      url: "https://data-seed-prebsc-2-s3.binance.org:8545",
      chainId: 97,
      accounts: [""],
    },
    evmos: {
      url: "https://eth.bd.evmos.org:8545",
      chainId: 9001,
      accounts: [""],
    },
    evmos_testnet: {
      url: "https://eth.bd.evmos.dev:8545",
      chainId: 9000,
      accounts: [""],
    },
    klaytn_baobab: {
      url: "https://api.baobab.klaytn.net:8651/",
      chainId: 1001,
      gasPrice: 250000000000,
      accounts: [""],
    },
  },
  paths: {
    artifacts: "./artifacts",
    sources: "./contracts",
    cache: "./cache",
    tests: "./test",
  },
  mocha: {
    timeout: 100000000000000,
  },
};

export default config;
