// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("LockModule", (m) => {

  const ERC20 = "0x7169D38820dfd117C3FA1f22a697dBA58d90BA06";
  const BEP20 = "0xA11c8D9DC9b66E209Ef60F0C8D969D3CD988782c"
  const lock = m.contract("ChainSphereTokenICO", [ERC20,BEP20]);

  return { lock };
});


// 0x3237A341cc60C9c5dADD84D7A20060Ff6bBdaDd5