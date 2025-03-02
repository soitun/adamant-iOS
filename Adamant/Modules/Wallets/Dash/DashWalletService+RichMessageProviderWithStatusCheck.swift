//
//  DashWalletService+RichMessageProviderWithStatusCheck.swift
//  Adamant
//
//  Created by Anton Boyarkin on 26/05/2019.
//  Copyright © 2019 Adamant. All rights reserved.
//

import Foundation
import CommonKit

extension DashWalletService {
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
        
        let dashTransaction: BTCRawTransaction
        
        do {
            dashTransaction = try await getTransaction(by: hash, waitsForConnectivity: true)
        } catch {
            return .init(error: error)
        }
        
        return await .init(
            sentDate: dashTransaction.date,
            status: getStatus(dashTransaction: dashTransaction, transaction: transaction)
        )
    }
}

private extension DashWalletService {
    func getStatus(
        dashTransaction: BTCRawTransaction,
        transaction: CoinTransaction
    ) async -> TransactionStatus {
        // MARK: Check confirmations
        
        guard let confirmations = dashTransaction.confirmations, let dashDate = dashTransaction.date, (confirmations > 0 || dashDate.timeIntervalSinceNow > -60 * 15) else {
            return .registered
        }
        
        // MARK: Check amount & address
        guard let reportedValue = reportedValue(for: transaction) else {
            return .inconsistent(.wrongAmount)
        }
        
        let min = reportedValue - reportedValue*0.005
        let max = reportedValue + reportedValue*0.005
        
        guard let walletAddress = dashWallet?.address else {
            return .inconsistent(.unknown)
        }
        
        let readableTransaction = dashTransaction.asBtcTransaction(DashTransaction.self, for: walletAddress)
        
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
        
        guard readableTransaction.senderAddress.caseInsensitiveCompare(realSenderAddress) == .orderedSame else {
            return .inconsistent(.senderCryptoAddressMismatch(tokenSymbol))
        }
        
        guard readableTransaction.recipientAddress.caseInsensitiveCompare(realRecipientAddress) == .orderedSame else {
            return .inconsistent(.recipientCryptoAddressMismatch(tokenSymbol))
        }
        
        var result: TransactionStatus = .inconsistent(.wrongAmount)
        if transaction.isOutgoing {
            guard readableTransaction.senderAddress.caseInsensitiveCompare(walletAddress) == .orderedSame else {
                return .inconsistent(.senderCryptoAddressMismatch(tokenSymbol))
            }
            
            var totalIncome: Decimal = 0
            for output in dashTransaction.outputs {
                guard !output.addresses.contains(walletAddress) else {
                    continue
                }
                
                totalIncome += output.value
            }
            
            if (min...max).contains(totalIncome) {
                result = .success
            }
        } else {
            guard readableTransaction.recipientAddress.caseInsensitiveCompare(walletAddress) == .orderedSame else {
                return .inconsistent(.recipientCryptoAddressMismatch(tokenSymbol))
            }
            
            var totalOutcome: Decimal = 0
            for output in dashTransaction.outputs {
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
