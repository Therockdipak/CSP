// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {

  const address = "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd";
  const lock = m.contract("ChainSphereTokenICO", [address]);

  return { lock };
});
