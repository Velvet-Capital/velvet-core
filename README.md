## Running test cases

Install Dependencies:

```
$ npm i --legacy-peer-deps
```

To run the testcases, make sure that the `.env` file is updated (with the RPC URLs, ENSO_KEY ,CHAIN_ID and the wallet mnemonic value).

To run the testcases of Arbitrum(set CHAIN_ID="42161" in env), run the following command:

```
$ npx hardhat test test/Arbitrum/*test.*
```

To run the testcases of Bsc(set CHAIN_ID="56" in env), run the following command:

```
$ npx hardhat test test/Bsc/*test.*
```

To run the coverage of Arbitrum(set CHAIN_ID="42161" in env), run the following command:

```
$ npm run coverageArbitrum
```

To run the coverage of Bsc(set CHAIN_ID="56" in env), run the following command:

```
$ npm run coverageBsc
```