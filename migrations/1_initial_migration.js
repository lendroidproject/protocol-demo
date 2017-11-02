var NetworkParameters = artifacts.require("./NetworkParameters.sol");

module.exports = function(deployer) {
  deployer.deploy(NetworkParameters);
};
