//
//  Wallet.swift
//  Adamant
//
//  Created by Anokhov Pavel on 03.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import UIKit
import Swinject
import CommonKit

enum WalletServiceState: Equatable {
    case notInitiated, updating, upToDate, initiationFailed(reason: String)
}

enum WalletServiceSimpleResult {
    case success
    case failure(error: WalletServiceError)
}

typealias WalletServiceResult<T: Sendable> = Result<T, WalletServiceError>

// MARK: - Errors

enum WalletServiceError: Error, Sendable {
    case notLogged
    case notEnoughMoney
    case networkError
    case accountNotFound
    case walletNotInitiated
    case invalidAmount(Decimal)
    case remoteServiceError(message: String, error: Error?)
    case apiError(ApiServiceError)
    case internalError(message: String, error: Error?)
    case transactionNotFound(reason: String)
    case requestCancelled
    case dustAmountError
}

extension WalletServiceError: RichError {
    var message: String {
        switch self {
        case .notLogged:
            return String.adamant.sharedErrors.userNotLogged
            
        case .notEnoughMoney:
            return String.adamant.sharedErrors.notEnoughMoney
            
        case .networkError:
            return String.adamant.sharedErrors.networkError
            
        case .accountNotFound:
            return String.adamant.transfer.accountNotFound
            
        case .walletNotInitiated:
            return .localized("WalletServices.SharedErrors.WalletNotInitiated", comment: "Wallet Services: Shared error, user has not yet initiated a specific wallet.")
            
        case .remoteServiceError(let message, let error):
            return String.adamant.sharedErrors.remoteServerError(message: message)
            
        case .apiError(let error):
            return error.localizedDescription
            
        case .internalError(let message, _):
            return String.adamant.sharedErrors.internalError(message: message)
            
        case .invalidAmount(let amount):
            return String.localizedStringWithFormat(.localized("WalletServices.SharedErrors.InvalidAmountFormat", comment: "Wallet Services: Shared error, invalid amount format. %@ for amount"), AdamantBalanceFormat.full.format(amount))
            
        case .transactionNotFound:
            return .localized("WalletServices.SharedErrors.TransactionNotFound", comment: "Wallet Services: Shared error, transaction not found")
            
        case .requestCancelled:
            return String.adamant.sharedErrors.requestCancelled
        case .dustAmountError:
            return String.adamant.sharedErrors.dustError
        }
    }
    
    var internalError: Error? {
        switch self {
        case .internalError(_, let error): return error
        default: return nil
        }
    }
    
    var level: ErrorLevel {
        switch self {
        case .notLogged, .notEnoughMoney, .networkError, .accountNotFound, .invalidAmount, .walletNotInitiated, .transactionNotFound, .requestCancelled:
            return .warning
        
        case .dustAmountError, .remoteServiceError:
            return .error
            
        case .internalError:
            return .internalError
            
        case .apiError(let error):
            return error.level
        }
    }
    
    static func internalError(_ error: InternalAPIError) -> Self {
        .internalError(message: error.localizedDescription, error: error)
    }
    
    static func remoteServiceError(message: String? = nil, error: Error? = nil) -> Self {
        .remoteServiceError(
            message: message ?? error?.localizedDescription ?? .empty,
            error: error
        )
    }
}

extension WalletServiceError: HealthCheckableError {
    var isNetworkError: Bool {
        switch self {
        case .networkError:
            return true
        default:
            return false
        }
    }
    
    public static var noNetworkError: WalletServiceError {
        .apiError(.noNetworkError)
    }
    
    static func noEndpointsError(nodeGroupName: String) -> WalletServiceError {
        .apiError(.noEndpointsError(nodeGroupName: nodeGroupName))
    }
}

extension ApiServiceError {
    func asWalletServiceError() -> WalletServiceError {
        switch self {
        case .accountNotFound:
            return .accountNotFound
            
        case .networkError:
            return .networkError
            
        case .notLogged:
            return .notLogged
            
        case .requestCancelled:
            return .requestCancelled
            
        case .serverError, .internalError, .commonError, .noEndpointsAvailable:
            return .apiError(self)
        }
    }
}

extension ChatsProviderError {
    func asWalletServiceError() -> WalletServiceError {
        switch self {
        case .notLogged:
            return .notLogged
            
        case .messageNotValid:
            return .notLogged
            
        case .notEnoughMoneyToSend:
            return .notEnoughMoney
            
        case .networkError:
            return .networkError
            
        case .serverError(let e as ApiServiceError):
            return .apiError(e)
            
        case .serverError(let e):
            return .internalError(message: self.message, error: e)
            
        case .accountNotFound:
            return .accountNotFound
            
        case .dependencyError(let message):
            return .internalError(message: message, error: nil)
            
        case .transactionNotFound(let id):
            return .transactionNotFound(reason: "\(id)")
            
        case .internalError(let error):
            return .internalError(message: self.message, error: error)
            
        case .accountNotInitiated:
            return .walletNotInitiated
            
        case .requestCancelled:
            return .requestCancelled
            
        case .invalidTransactionStatus:
            return .internalError(message: "Invalid Transaction Status", error: nil)
        }
    }
}

// MARK: - Notifications
extension AdamantUserInfoKey {
    struct WalletService {
        static let wallet = "Adamant.WalletService.wallet"
        static let walletState = "Adamant.WalletService.walletState"
        
        private init() {}
    }
}

// MARK: - UI
extension Notification.Name {
    struct WalletViewController {
        static let heightUpdated = Notification.Name("adamant.walletViewController")
        
        private init() {}
    }
}

@MainActor
protocol WalletViewController {
    var viewController: UIViewController { get }
    var height: CGFloat { get }
    var service: WalletService? { get }
}

// MARK: - Wallet Service
protocol WalletCoreProtocol: AnyObject, Sendable {
    // MARK: Currency
    static var currencySymbol: String { get }
    static var currencyLogo: UIImage { get }
    static var qqPrefix: String { get }
    
    var tokenSymbol: String { get }
    var tokenName: String { get }
    var tokenLogo: UIImage { get }
    var tokenUnicID: String { get }
    static var tokenNetworkSymbol: String { get }
    var consistencyMaxTime: Double { get }
    var tokenContract: String { get }
    var minBalance: Decimal { get }
    var minAmount: Decimal { get }
    var defaultVisibility: Bool { get }
    var defaultOrdinalLevel: Int? { get }
    var richMessageType: String { get }
    var dynamicRichMessageType: String { get }
    var coinStorage: CoinStorageService { get }
    var nodeGroups: [NodeGroup] { get }
    var transferDecimals: Int { get }
    var explorerAddress: String { get }
    
    var transactionsPublisher: AnyObservable<[TransactionDetails]> {
        get
    }
    
    var hasMoreOldTransactionsPublisher: AnyObservable<Bool> {
        get
    }
    
    /// Lowercased!!
    static var richMessageType: String { get }
    
    // MARK: Transactions fetch info
    
    var newPendingInterval: TimeInterval { get }
    var oldPendingInterval: TimeInterval { get }
    var registeredInterval: TimeInterval { get }
    var newPendingAttempts: Int { get }
    var oldPendingAttempts: Int { get }
    
    // MARK: Notifications
    
    /// Wallet updated.
    /// UserInfo contains new wallet at AdamantUserInfoKey.WalletService.wallet
    var walletUpdatedNotification: Notification.Name { get }
    
    /// Enabled state changed
    var serviceEnabledChanged: Notification.Name { get }
    
    /// State changed
    var serviceStateChanged: Notification.Name { get }
    
    // MARK: State
    var wallet: WalletAccount? { get }
    var state: WalletServiceState { get }
    var enabled: Bool { get }
    
    // MARK: Logic
    @MainActor
    var hasEnabledNode: Bool { get }
    
    @MainActor
    var hasEnabledNodePublisher: AnyObservable<Bool> { get }
    
    func update()
    
    // MARK: Tools
    func validate(address: String) -> AddressValidationResult
    func getWalletAddress(byAdamantAddress address: String) async throws -> String
    func getBalance(address: String) async throws -> Decimal
    func loadTransactions(offset: Int, limit: Int) async throws -> Int
    func getLocalTransactionHistory() -> [TransactionDetails]
    func getTransactionsHistory(offset: Int, limit: Int) async throws -> [TransactionDetails]
    func updateStatus(for id: String, status: TransactionStatus?)
    func isExist(address: String) async throws -> Bool
    func statusInfoFor(transaction: CoinTransaction) async -> TransactionStatusInfo
    func initWallet(withPassphrase: String) async throws -> WalletAccount
    func setInitiationFailed(reason: String)
    func shortDescription(for transaction: RichMessageTransaction) -> NSAttributedString
    func getFee(comment: String) -> Decimal
    
    // MARK: Send
    
    var transactionFeeUpdated: Notification.Name { get }
    
    var qqPrefix: String { get }
    var blockchainSymbol: String { get }
    var isDynamicFee : Bool { get }
    var diplayTransactionFee : Decimal { get }
    var transactionFee : Decimal { get }
    var isWarningGasPrice : Bool { get }
    var isTransactionFeeValid : Bool { get }
    var commentsEnabledForRichMessages: Bool { get }
    var isSupportIncreaseFee: Bool { get }
    var isIncreaseFeeEnabled: Bool { get }
    var defaultIncreaseFee: Decimal { get }
    var additionalFee : Decimal { get }
}

extension WalletCoreProtocol {
    func isExist(address: String) async throws -> Bool { return true }
    func getFee(comment: String) -> Decimal { transactionFee }
}

extension WalletCoreProtocol {
    var isTransactionFeeValid: Bool {
        return true
    }
    var diplayTransactionFee: Decimal {
        return transactionFee
    }
    var commentsEnabledForRichMessages: Bool {
        return true
    }
    var blockchainSymbol: String {
        return tokenSymbol
    }
    var isDynamicFee: Bool {
        return false
    }
    var isSupportIncreaseFee: Bool {
        return false
    }
    var isIncreaseFeeEnabled: Bool {
        return false
    }
    var defaultIncreaseFee: Decimal {
        return 1.5
    }
    var additionalFee: Decimal {
        .zero
    }
}

protocol SwinjectDependentService: WalletCoreProtocol {
    @MainActor
    func injectDependencies(from container: Container)
}

// MARK: Send

protocol WalletServiceSimpleSend: WalletCoreProtocol {
    func sendMoney(
        recipient: String,
        amount: Decimal,
        comments: String,
        replyToMessageId: String?
    ) async throws -> AdamantTransactionDetails
}

protocol WalletServiceTwoStepSend: WalletCoreProtocol {
    associatedtype T: RawTransaction
    
    func createTransaction(
        recipient: String,
        amount: Decimal,
        fee: Decimal,
        comment: String?
    ) async throws -> T
    
    func sendTransaction(_ transaction: T) async throws
}

protocol RawTransaction {
    var txHash: String? { get }
}

extension WalletCoreProtocol {
    static var balanceLifetime: TimeInterval { 300 }
}
