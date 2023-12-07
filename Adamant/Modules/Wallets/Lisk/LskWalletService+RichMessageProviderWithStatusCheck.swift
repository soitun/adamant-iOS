//
//  LskWalletService+RichMessageProviderWithStatusCheck.swift
//  Adamant
//
//  Created by Anton Boyarkin on 06/12/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import LiskKit
import CommonKit

extension LskWalletService {
    func statusInfoFor(transaction: CoinTransaction) async -> TransactionStatusInfo {
        let hash: String?
        
        if let transaction = transaction as? RichMessageTransaction {
            hash = transaction.getRichValue(for: RichContentKeys.transfer.hash)
        } else {
            hash = transaction.txId
        }
        
        guard let hash = hash else {
            return .init(sentDate: nil, status: .inconsistent(.wrongTxHash))
        }
        
        var lskTransaction: Transactions.TransactionModel
        
        do {
            lskTransaction = try await getTransaction(by: hash)
        } catch {
            return .init(error: error)
        }
        
        lskTransaction.updateConfirmations(value: lastHeight)
        
        return .init(
            sentDate: lskTransaction.sentDate,
            status: getStatus(
                lskTransaction: lskTransaction,
                transaction: transaction
            )
        )
    }
}

private extension LskWalletService {
    func getStatus(
        lskTransaction: Transactions.TransactionModel,
        transaction: CoinTransaction
    ) -> TransactionStatus {
        guard lskTransaction.blockId != nil else { return .registered }
        
        guard let status = lskTransaction.transactionStatus else {
            return .inconsistent(.unknown)
        }
        
        guard status == .success else {
            return status
        }
        
        // MARK: Check address
        if transaction.isOutgoing {
            guard lskTransaction.senderAddress == lskWallet?.address else {
                return .inconsistent(.senderCryptoAddressMismatch)
            }
        } else {
            guard lskTransaction.recipientAddress == lskWallet?.address else {
                return .inconsistent(.recipientCryptoAddressMismatch)
            }
        }
        
        // MARK: Check amount
        guard isAmountCorrect(
            transaction: transaction,
            lskTransaction: lskTransaction
        ) else { return .inconsistent(.wrongAmount) }
        
        return .success
    }
    
    func isAmountCorrect(
        transaction: CoinTransaction,
        lskTransaction: Transactions.TransactionModel
    ) -> Bool {
        if let transaction = transaction as? RichMessageTransaction,
           let raw = transaction.getRichValue(for: RichContentKeys.transfer.amount),
           let reported = AdamantBalanceFormat.deserializeBalance(from: raw) {
            let min = reported - reported*0.005
            let max = reported + reported*0.005
            
            let amount = lskTransaction.amountValue ?? 0
            return amount <= max && amount >= min
        }
        
        return transaction.amountValue == lskTransaction.amountValue
    }
}
