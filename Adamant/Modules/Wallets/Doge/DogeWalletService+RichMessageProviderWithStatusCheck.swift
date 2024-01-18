//
//  DogeWalletService+RichMessageProviderWithStatusCheck.swift
//  Adamant
//
//  Created by Anton Boyarkin on 13/03/2019.
//  Copyright © 2019 Adamant. All rights reserved.
//

import Foundation
import CommonKit

extension DogeWalletService {
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
        
        let dogeTransaction: BTCRawTransaction
        
        do {
            dogeTransaction = try await getTransaction(by: hash)
        } catch {
            return .init(error: error)
        }
        
        return await .init(
            sentDate: dogeTransaction.date,
            status: getStatus(
                dogeTransaction: dogeTransaction,
                transaction: transaction
            )
        )
    }
}

private extension DogeWalletService {
    func getStatus(
        dogeTransaction: BTCRawTransaction,
        transaction: CoinTransaction
    ) async -> TransactionStatus {
        // MARK: Check confirmations
        guard let confirmations = dogeTransaction.confirmations,
              let dogeDate = dogeTransaction.date,
              (confirmations > 0 || dogeDate.timeIntervalSinceNow > -60 * 15)
        else {
            return .pending
        }
        
        // MARK: Check amount & address
        guard let reportedValue = reportedValue(for: transaction) else {
            return .inconsistent(.wrongAmount)
        }
        
        let min = reportedValue - reportedValue*0.005
        let max = reportedValue + reportedValue*0.005
        
        guard let walletAddress = dogeWallet?.address else {
            return .inconsistent(.unknown)
        }
        
        let readableTransaction = dogeTransaction.asBtcTransaction(DogeTransaction.self, for: walletAddress)
        
        var realSenderAddress = readableTransaction.senderAddress
        var realRecipientAddress = readableTransaction.recipientAddress
        
        if transaction is RichMessageTransaction {
            guard let senderAddress = try? await getWalletAddress(byAdamantAddress: transaction.senderAddress)
            else {
                return .inconsistent(.senderCryptoAddressUnavailable(tokenSymbol))
            }
            
            guard let recipientAddress = try? await getWalletAddress(byAdamantAddress: transaction.recipientAddress)
            else {
                return .inconsistent(.recipientCryptoAddressUnavailable(tokenSymbol))
            }
            
            realSenderAddress = senderAddress
            realRecipientAddress = recipientAddress
        }
        
        guard realSenderAddress == readableTransaction.senderAddress else {
            return .inconsistent(.senderCryptoAddressMismatch(tokenSymbol))
        }
        
        guard realRecipientAddress == readableTransaction.recipientAddress else {
            return .inconsistent(.recipientCryptoAddressMismatch(tokenSymbol))
        }
        
        var result: TransactionStatus = .inconsistent(.wrongAmount)
        if transaction.isOutgoing {
            guard readableTransaction.senderAddress == walletAddress else {
                return .inconsistent(.senderCryptoAddressMismatch(tokenSymbol))
            }
            
            var totalIncome: Decimal = 0
            for output in dogeTransaction.outputs {
                guard !output.addresses.contains(walletAddress) else {
                    continue
                }
                
                totalIncome += output.value
            }
            
            if (min...max).contains(totalIncome) {
                result = .success
            }
        } else {
            guard readableTransaction.recipientAddress == walletAddress else {
                return .inconsistent(.recipientCryptoAddressMismatch(tokenSymbol))
            }
            
            var totalOutcome: Decimal = 0
            for output in dogeTransaction.outputs {
                guard output.addresses.contains(walletAddress) else {
                    continue
                }
                
                totalOutcome += output.value
            }
            
            if (min...max).contains(totalOutcome) {
                result = .success
            }
        }
        
        return result
    }
    
    func reportedValue(for transaction: CoinTransaction) -> Decimal? {
        guard let transaction = transaction as? RichMessageTransaction
        else {
            return transaction.amountValue
        }
        
        guard
            let raw = transaction.getRichValue(for: RichContentKeys.transfer.amount),
            let reportedValue = AdamantBalanceFormat.deserializeBalance(from: raw)
        else {
            return nil
        }
        
        return reportedValue
    }
}
