//
//  EthWalletService.swift
//  Adamant
//
//  Created by Anokhov Pavel on 03.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

class EthWalletService: WalletService {
	// MARK: - Constants
	typealias wallet = EthWallet
	let transactionFee: Decimal = 0.0
	
	// MARK: - Properties
	let enabled = true
	
	// MARK: - Logic
	func getAccountInfo(for address: String) -> EthWallet? {
		return nil
	}
	
	// MARK: - Tools
	func validate(address: String) -> AddressValidationResult {
		return .valid
	}
}
