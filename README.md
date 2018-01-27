Protocol-demo
=============
This repository of smart contracts contains the  Lendroid Protocol to demonstrate Leverage on-chain using 0x and Relayers

Experimental code
=================
This repository contains experimental code and is not suitable for production usage.        

Smart Contracts
===============
The smart contracts are being built using truffle, and tested on the Kovan network. All contracts currently belong in the same file for ease of use while importing to the Remix IDE for quick tests.
<details>
    <summary>
        Oracle.sol
    </summary>
    <p>
        Provides price feeds sourced from various price feed providers
    </p>
</details>
<details>
    <summary>
      PriceFeed module
    </summary>
    <p>
        Currently uses price feed from api.coinmarketcap.com via Oraclize. This module is open to contributors who can add their own PriceFeedProvider contracts (extend PriceFeedProviderBase.sol)
    </p>
</details>
<details>
    <summary>
      Wallet.sol
    </summary>
    <p>Contains business logic to calculate Lender, Margin account, & Wrangler balances. Also calculates margin balances.
    </p>
</details>
<details>
    <summary>
      LoanManager.sol
    </summary>
    <p>Handles loans. Contains simple CRUD operations on Loan objects.
    </p>
</details>
<details>
    <summary>
      PositionManager.sol
    </summary>
    <p>Handles positions. Contains simple CRUD operations on Position objects.
    </p>
</details>
<details>
    <summary>
      A placeholder OrderManager.sol
    </summary>
    <p>Temporarily handles orders for demo purposes.
    </p>
</details>

Running the code
================

> git clone git@github.com:gedanziger/protocol-demo.git

> cp data_snapshot data

> docker-compose run --rm geth_rpc --identity LocalNode --datadir ./data --networkid 1999 removedb

> docker-compose run --rm geth_rpc --identity LocalNode --datadir ./data --networkid 1999 account new --password <(echo 123456qwerty)

> docker-compose run --rm geth_rpc --identity LocalNode --datadir ./data --networkid 1999 init ./data/genesis.json

> docker-compose run --rm geth_rpc --identity LocalNode --datadir ./data --networkid 1999 --gasprice 1

>  docker-compose run --rm geth_rc --identity LocalNode --datadir ./data --networkid 1999 console
