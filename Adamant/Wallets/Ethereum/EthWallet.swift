//
//  EthWallet.swift
//  Adamant
//
//  Created by Anokhov Pavel on 03.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import web3swift

struct EthWallet: WalletAccount {
	let address: String
	let balance: Decimal
	
	let ethAddress: EthereumAddress
	
	func formatBalance(format: BalanceFormat, includeCurrencySymbol: Bool) -> String {
		if includeCurrencySymbol {
			return "\(format.defaultFormatter.string(from: balance as NSNumber)!) \(LskWalletService.currencySymbol)"
		} else {
			return format.defaultFormatter.string(from: balance as NSNumber)!
		}
	}
}
