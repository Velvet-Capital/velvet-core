// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

abstract contract Addresses {
  address public constant USD = 0x0000000000000000000000000000000000000348;
  address public constant BSC_ETH_DEFAULT =
    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  address public constant BSC_ADA = 0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47;
  address public constant BSC_BAND = 0xAD6cAEb32CD2c308980a548bD0Bc5AA4306c6c18;
  address public constant BSC_BTC = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
  address public constant BSC_BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  address public constant BSC_BUSDT =
    0x55d398326f99059fF775485246999027B3197955;
  address public constant BSC_CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
  address public constant BSC_DAI = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
  address public constant BSC_DOT = 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402;
  address public constant BSC_ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address public constant BSC_DOGE = 0xbA2aE424d960c26247Dd6c32edC70B295c744C43;
  address public constant BSC_WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address public constant BSC_LINK = 0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD;
  address public constant BSC_XVS = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;

  // // Alpaca
  // address public constant BSC_ibBNB_Address = 0xd7D069493685A581d27824Fc46EdA46B7EfC0063;
  // address public constant BSC_ibBTCB_Address = 0x08FC9Ba2cAc74742177e0afC3dC8Aed6961c24e7;
  // address public constant BSC_ibUSDT = 0x158Da805682BdC8ee32d52833aD41E74bb951E59;

  // ApeSwapLP Pool
  address public constant BSC_ApeSwap_WBNB_BUSD_Address =
    0x51e6D27FA57373d8d4C256231241053a70Cb1d93;
  address public constant BSC_ApeSwap_ETH_BTCB_Address =
    0xc6EA23E8aDAf03E700be3AA50bE30ECd39B7bF49;
  address public constant BSC_ApeSwap_ETH_WBNB_Address =
    0xA0C3Ef24414ED9C9B456740128d8E63D016A9e11;
  address public constant BSC_ApeSwap_USDT_WBNB_Address =
    0x83C5b5b309EE8E232Fe9dB217d394e262a71bCC0;
  address public constant BSC_ApeSwap_DOGE_WBNB_Address =
    0xfd1ef328A17A8e8Eeaf7e4Ea1ed8a108E1F2d096;

  // ApeSwapLending
  address public constant BSC_oBNB = 0x34878F6a484005AA90E7188a546Ea9E52b538F6f;
  address public constant BSC_oETH = 0xaA1b1E1f251610aE10E4D553b05C662e60992EEd;
  address public constant BSC_oBTCB =
    0x5fce5D208DC325ff602c77497dC18F8EAdac8ADA;
  address public constant BSC_oBUSD =
    0x0096B6B49D13b347033438c4a699df3Afd9d2f96;

  // BiswapLP Pool
  address public constant BSC_BSwap_WBNB_BUSDLP_Address =
    0xaCAac9311b0096E04Dfe96b6D87dec867d3883Dc;
  address public constant BSC_BSwap_BUSDT_BUSDLP_Address =
    0xDA8ceb724A06819c0A5cDb4304ea0cB27F8304cF;
  address public constant BSC_BSwap_BUSDT_WBNBLP_Address =
    0x8840C6252e2e86e545deFb6da98B2a0E26d8C1BA;
  address public constant BSC_BSwap_ETH_BTCLP_Address =
    0x6216E04cd40DB2c6FBEd64f1B5830A98D3A91740;
  address public constant BSC_BSwap_BTC_WBNBLP_Address =
    0xC7e9d76ba11099AF3F330ff829c5F442d571e057;
  address public constant BSC_BSwap_DOGE_WBNBLPAddress =
    0x1eF315fa08e0E1B116D97E3dFE0aF292Ed8b7f02;

  //Beefy
  address public constant BSC_mooValasUSDC =
    0x517493d1Fb90aB0a3cE3a5084065B706e33e0fEA;
  address public constant BSC_mooVenusBNB =
    0x6BE4741AB0aD233e4315a10bc783a7B923386b71;
  address public constant BSC_mooValasBUSD =
    0xB78b6A0137ad8745784D3B23c16abeA8F527ff54;
  address public constant BSC_mooValasETH =
    0x725E14C3106EBf4778e01eA974e492f909029aE8;

  //BeefyLP
  address public constant BSC_mooBTCBETH =
    0xEf43E54Bb4221106953951238FC301a1f8939490; //BeefyLP
  address public constant BSC_mooDOGEWBNB =
    0x3b3bc8AE6dcAcCeaaC3C19E196ebD3341Cfe9c4e;
  address public constant BSC_mooCAKEWBNB =
    0xb26642B6690E4c4c9A6dAd6115ac149c700C7dfE;
  address public constant BSC_mooCAKEUSDT =
    0x969b3fb717C432735088e9e7A7F261F37fb2e526;
  address public constant BSC_mooXVSBNB =
    0xa2f05EA4Af928BA34d66E6f69343a6703744Caba; //BeefyLP
  address public constant BSC_mooETHBNB =
    0x0eb78598851D08218d54fCe965ee2bf29C288fac; //BeefyLP

  // PancakeLP Pool
  address public constant BSC_WBNB_BUSDLP_Address =
    0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
  address public constant BSC_Cake_BUSDLP_Address =
    0x804678fa97d91B974ec2af3c843270886528a9E6;
  address public constant BSC_Cake_WBNBLP_Address =
    0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
  address public constant BSC_ADA_WBNBLP_Address =
    0x28415ff2C35b65B9E5c7de82126b4015ab9d031F;
  address public constant BSC_BAND_WBNBLP_Address =
    0x168B273278F3A8d302De5E879aA30690B7E6c28f;
  address public constant BSC_DOT_WBNBLP_Address =
    0xDd5bAd8f8b360d76d12FdA230F8BAF42fe0022CF;
  address public constant BSC_DOGE_WBNBLP_Address =
    0xac109C8025F272414fd9e2faA805a583708A017f;
  address public constant BSC_BUSD_BTCLP_Address =
    0xF45cd219aEF8618A92BAa7aD848364a158a24F33;
  address public constant BSC_BTC_WBNBLP_Address =
    0x61EB789d75A95CAa3fF50ed7E47b96c132fEc082;
  address public constant BSC_ETH_BTCLP_Address =
    0xD171B26E4484402de70e3Ea256bE5A2630d7e88D;
  address public constant BSC_WBNB_XVSLP_Address =
    0x7EB5D86FD78f3852a3e0e064f2842d45a3dB6EA2;
  address public constant BSC_ETH_WBNBLP_Address =
    0x74E4716E431f45807DCF19f284c7aA99F18a4fbc;
  address public constant BSC_CAKE_USDTLP_Address =
    0xA39Af17CE4a8eb807E076805Da1e2B8EA7D0755b;

  // Venus
  address public constant BSC_vBNB_Address =
    0xA07c5b74C9B40447a954e1466938b865b6BBea36;
  address public constant BSC_vETH_Address =
    0xf508fCD89b8bd15579dc79A6827cB4686A3592c8;
  address public constant BSC_vDAI_Address =
    0x334b3eCB4DCa3593BCCC3c7EBD1A1C1d1780FBF1;
  address public constant BSC_vBTC_Address =
    0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B;
  address public constant BSC_vDOGE_Address =
    0xec3422Ef92B2fb59e84c8B02Ba73F1fE84Ed8D71;
  address public constant BSC_vLINK_Address =
    0x650b940a1033B8A1b1873f78730FcFC73ec11f1f;

  // Wombat
  address public constant BSC_MAIN_LP_BUSD =
    0xF319947eCe3823b790dd87b0A509396fE325745a;
  address public constant BSC_MAIN_LP_DAI =
    0x9D0a463D5dcB82008e86bF506eb048708a15dd84;
  address public constant BSC_SIDE_LP_BUSD =
    0xA649Be04619a8F3B3475498E1ac15C90C9661C1A;
  address public constant BSC_LP_BNBx =
    0x0321D1D769cc1e81Ba21a157992b635363740f86;
  address public constant BSC_stkBNB_LP_WBNB =
    0x6C7B407411b3DB90DfA25DA4aA66605438D378CE;

  // Reward tokens
  address public constant BSC_BASE_REWARD =
    0x0000000000000000000000000000000000000000;
  address public constant BSC_VENUS_REWARD =
    0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;
  address public constant BSC_WOMBAT_REWARD =
    0xAD6742A35fB341A9Cc6ad674738Dd8da98b94Fb1;
  address public constant BSC_CAKE_REWARD =
    0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
  address public constant BSC_APESWAP_REWARD =
    0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95;
  address public constant BSC_BISWAP_REWARD =
    0x965F527D9159dCe6288a2219DB51fc6Eef120dD1;
  address public constant BSC_ALPACA_REWARD =
    0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F;

  // Gnosis Deployment
  address public constant BSC_GNOSIS_SINGLETON =
    0x3E5c63644E683549055b9Be8653de26E0B4CD36E;
  address public constant BSC_GNOSIS_FALLBACK_LIB =
    0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;
  address public constant BSC_GNOSIS_MULTISEND_LIB =
    0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
  address public constant BSC_GNOSIS_SAFE_PROXY_FACTORY =
    0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
}
