require("dotenv/config");
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
require("hardhat-gas-reporter");
/** @type import('hardhat/config').HardhatUserConfig */

// 
const mnemonic = process.env.MNEMONIC;
if (!mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const infuraApiKey = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error("Please set your ALCHEMY_API_KEY in a .env file");
}

const chainIds = {
  "arbitrum-mainnet": 42161,
  avalanche: 43114,
  bsc: 56,
  hardhat: 31337,
  mainnet: 1,
  "optimism-mainnet": 10,
  "polygon-mainnet": 137,
  "polygon-amoy": 80002,
  sepolia: 11155111,
  holesky: 17000,
  "kyoto-testnet": 1998,
  "aurora-testnet": 1313161555,
  "aurora-mainnet": 1313161554,
  "bsc-testnet": 97
};

function getChainConfig(chain) {
  let jsonRpcUrl = "";

  switch (chain) {
    case "avalanche":
      jsonRpcUrl = "https://api.avax.network/ext/bc/C/rpc";
      break;
    case "bsc-testnet":
      // jsonRpcUrl = "https://bsc-dataseed1.binance.org";
      jsonRpcUrl ="https://bsc-testnet-dataseed.bnbchain.org";
      break;

    case "aurora-testnet":
      jsonRpcUrl = "https://testnet.aurora.dev";
      break;
    case "aurora-mainnnet":
      jsonRpcUrl = "https://mainnet.aurora.dev";
      break;

    case "kyoto-testnet":
      jsonRpcUrl = `https://rpc.testnet.kyotoprotocol.io:8545`;
      break;
    default:
      jsonRpcUrl = `https://${chain}.infura.io/v3/${infuraApiKey}`;
  }
  return {
    accounts: {
      count: 10,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
    chainId: chainIds[chain],
    url: jsonRpcUrl,
  };
}

const network =
  process.env.TESTING === "true"
    ? "hardhat"
    : process.env.DEPLOY_NETWORK || "sepolia";

const config = {
  defaultNetwork: network,
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      avalanche: process.env.SNOWTRACE_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      optimisticEthereum: process.env.OPTIMISM_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonAmoy: process.env.POLYGONSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY,
      holesky: process.env.ETHERSCAN_API_KEY,
    },
    // customChains: [
    //   {
    //     network: "polygon-amoy",
    //     chainId: 80002,
    //     urls: {
    //       apiURL: `https://api-amoy.polygonscan.com/api`,
    //       browserURL: `https://polygonscan.com/`,
    //     },
    //   },
    // ],
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
    gasPrice: 100000000000,
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic,
      },
      pollingInterval: 8000,
      chainId: chainIds.hardhat,
    },
    arbitrum: getChainConfig("arbitrum-mainnet"),
    avalanche: getChainConfig("avalanche"),
   "bsc-testnet": getChainConfig("bsc-testnet"),
    mainnet: getChainConfig("mainnet"),
    optimism: getChainConfig("optimism-mainnet"),
    "polygon-mainnet": getChainConfig("polygon-mainnet"),
    polygonAmoy: getChainConfig("polygon-amoy"),
    "kyoto-testnet": getChainConfig("kyoto-testnet"),
    "aurora-testnet": getChainConfig("aurora-testnet"),
    "aurora-mainnet": getChainConfig("aurora-mainnet"),
    sepolia: getChainConfig("sepolia"),
    holesky: getChainConfig("holesky"),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.28",
    settings: {
      metadata: {
        bytecodeHash: "none",
      },
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  typechain: {
    outDir: "src/types",
    target: "ethers-v5",
  },
  sourcify: {
    enabled: false,
  },
};

module.exports = config;