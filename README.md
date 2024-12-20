## Documentation for integration: 
https://docs.google.com/document/d/1jtl_WuikJDtpuzBMcuyhbHcgojhRO5gzmiQdd_JJVoU/edit?tab=t.0

## Subgraph: 
https://github.com/Velvet-Capital/velvet-core-subgraph/tree/graph-setup/velvet-core

## Running test cases

Install Dependencies:

```shell
npm i --legacy-peer-deps
```

To run the testcases, make sure that the `.env` file is updated (with the RPC URLs, ENSO_KEY ,CHAIN_ID and the wallet mnemonic value).

To run the testcases of Arbitrum(set CHAIN_ID="42161" in env), run the following command:

```shell
npx hardhat test test/Arbitrum/*test.*
```

To run the testcases of Bsc(set CHAIN_ID="56" in env), run the following command:

```shell
npx hardhat test test/Bsc/*test.*
```

Running a single test module:

```shell
npx hardhat test test/Bsc/1_IndexConfig.test.ts
```

To run the coverage of Arbitrum(set CHAIN_ID="42161" in env), run the following command:

```shell
npm run coverageArbitrum
```

To run the coverage of Bsc(set CHAIN_ID="56" in env), run the following command:

```shell
npm run coverageBsc
```
