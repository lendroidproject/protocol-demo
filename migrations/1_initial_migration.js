var NetworkParameters = artifacts.require("./NetworkParameters.sol");
var Oracle = artifacts.require("./Oracle.sol");
var Wallet = artifacts.require("./Wallet.sol");

module.exports = function(deployer) {
  deployer.deploy(NetworkParameters);
  deployer.deploy(Oracle);
  deployer.deploy(Wallet);
};
