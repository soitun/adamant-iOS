    import Foundation
    
    public extension ERC20Token {
        static let supportedTokens: [ERC20Token] = [
        
        ERC20Token(symbol: "BNB",
                   name: "Binance Coin",
                   contractAddress: "0xB8c77482e45F1F44dE1745F52C74426C631bDD52",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "BUSD",
                   name: "Binance USD",
                   contractAddress: "0x4fabb145d64652a948d72533023f6e7a623c7c53",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "DAI",
                   name: "Dai",
                   contractAddress: "0x6b175474e89094c44da98b954eedeac495271d0f",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: true,
                   defaultOrdinalLevel: 50,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "ENS",
                   name: "Ethereum Name Service",
                   contractAddress: "0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "HOT",
                   name: "Holo",
                   contractAddress: "0x6c6ee5e31d828de241282b9606c8e98ea48526e2",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "INJ",
                   name: "Injective",
                   contractAddress: "0xe28b3b32b6c345a34ff64674606124dd5aceca30",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "LINK",
                   name: "Chainlink",
                   contractAddress: "0x514910771af9ca656af840dff83e8264ecf986ca",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "MANA",
                   name: "Decentraland",
                   contractAddress: "0x0f5d2fb29fb7d3cfee444a200298f468908cc942",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "MATIC",
                   name: "Polygon",
                   contractAddress: "0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "PAXG",
                   name: "PAX Gold",
                   contractAddress: "0x45804880de22913dafe09f4980848ece6ecbaf78",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "QNT",
                   name: "Quant",
                   contractAddress: "0x4a220E6096B25EADb88358cb44068A3248254675",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "REN",
                   name: "Ren",
                   contractAddress: "0x408e41876cccdc0f92210600ef50372656052a38",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "SKL",
                   name: "SKALE",
                   contractAddress: "0x00c83aecc790e8a4453e5dd3b0b4b3680501a7a7",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "SNT",
                   name: "Status",
                   contractAddress: "0x744d70fdbe2ba4cf95131626614a1763df805b9e",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "SNX",
                   name: "Synthetix Network",
                   contractAddress: "0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "TUSD",
                   name: "TrueUSD",
                   contractAddress: "0x0000000000085d4780b73119b644ae5ecd22b376",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "UNI",
                   name: "Uniswap",
                   contractAddress: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "USDC",
                   name: "USD Coin",
                   contractAddress: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   decimals: 6,
                   naturalUnits: 6,
                   defaultVisibility: true,
                   defaultOrdinalLevel: 40,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "USDP",
                   name: "PAX Dollar",
                   contractAddress: "0x8e870d67f660d95d5be530380d0ec0bd388289e1",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "USDS",
                   name: "Stably USD",
                   contractAddress: "0xa4bdb11dc0a2bec88d24a3aa1e6bb17201112ebe",
                   decimals: 6,
                   naturalUnits: 6,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "USDT",
                   name: "Tether",
                   contractAddress: "0xdac17f958d2ee523a2206206994597c13d831ec7",
                   decimals: 6,
                   naturalUnits: 6,
                   defaultVisibility: true,
                   defaultOrdinalLevel: 30,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "VERSE",
                   name: "Verse",
                   contractAddress: "0x249cA82617eC3DfB2589c4c17ab7EC9765350a18",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: true,
                   defaultOrdinalLevel: 95,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "WOO",
                   name: "WOO Network",
                   contractAddress: "0x4691937a7508860f876c9c0a2a617e7d9e945d4b",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: false,
                   defaultOrdinalLevel: nil,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
        ERC20Token(symbol: "XCN",
                   name: "Onyxcoin",
                   contractAddress: "0xa2cd3d43c775978a96bdbf12d733d5a1ed94fb18",
                   decimals: 18,
                   naturalUnits: 18,
                   defaultVisibility: true,
                   defaultOrdinalLevel: 100,
                   reliabilityGasPricePercent: 10,
                   reliabilityGasLimitPercent: 10,
                   defaultGasPriceGwei: 30,
                   defaultGasLimit: 58000,
                   warningGasPriceGwei: 70),
    ]
    
}
