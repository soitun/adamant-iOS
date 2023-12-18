//
//  RichMessageProviderWithStatusCheck.swift
//  Adamant
//
//  Created by Andrey Golubenko on 26.03.2023.
//  Copyright © 2023 Adamant. All rights reserved.
//

import Foundation

struct TransactionStatusInfo {
    let sentDate: Date?
    let status: TransactionStatus
}

extension TransactionStatusInfo {
    init(error: Error) {
        switch error {
        case ApiServiceError.networkError,
            ApiServiceError.noEndpointsAvailable,
            WalletServiceError.networkError,
            WalletServiceError.apiError(.noEndpointsAvailable):
            self.init(sentDate: nil, status: .noNetwork)
        default:
            self.init(sentDate: nil, status: .pending)
        }
    }
}

protocol RichMessageProviderWithStatusCheck: RichMessageProvider {
    func statusInfoFor(transaction: CoinTransaction) async -> TransactionStatusInfo
}
