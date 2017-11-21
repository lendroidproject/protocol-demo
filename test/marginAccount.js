var Oracle = artifacts.require("Oracle");

contract('MarginAccount', function(accounts) {
  //console.log(accounts);

  it("should save token amount correctly", function(){
    var oracle;
    var user1 = accounts[0],
      user2 = accounts[1];
    console.log(user1);
    // return Oracle.deployed().then(function(instance) {
    //   oracle = instance;
    //   return oracle.stopped.call(user1);
    // }).then(function(value) {
    //   console.log(value);
    //   // user1 should not have been assigned a domain initially
    //   // assert.equal(domain.valueOf(), "0x0000000000000000000000000000000000000000000000000000000000000000", "user already has a domain");
    //   // return faucet.transferDomain.sendTransaction({from: user1, gasPrice: 2000000000})
    // }).then(function(result){
    //   //console.log(result);
    // });
  });

});
