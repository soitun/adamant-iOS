//
//  ERC20WalletService.swift
//  Adamant
//
//  Created by Anton Boyarkin on 26/06/2019.
//  Copyright © 2019 Adamant. All rights reserved.
//

import Foundation
import UIKit
import Swinject
import web3swift
import Alamofire
import struct BigInt.BigUInt
import Web3Core
import Combine
import CommonKit

final class ERC20WalletService: WalletService {
    // MARK: - Constants
    let addressRegex = try! NSRegularExpression(pattern: "^0x[a-fA-F0-9]{40}$")
    
    static var currencySymbol: String = ""
    static var currencyLogo: UIImage = UIImage()
    static var qqPrefix: String = ""
    
    var minBalance: Decimal = 0
    var minAmount: Decimal = 0
    
    var tokenSymbol: String {
        return token.symbol
    }
    
    var tokenName: String {
        return token.name
    }
    
    var tokenLogo: UIImage {
        return token.logo
    }
    
    var tokenNetworkSymbol: String {
        return "ERC20"
    }
    
    var consistencyMaxTime: Double {
        return 1200
    }
    
    var tokenContract: String {
        return token.contractAddress
    }
   
    var tokenUnicID: String {
        return tokenNetworkSymbol + tokenSymbol + tokenContract
    }
    
    var defaultVisibility: Bool {
        return token.defaultVisibility
    }
    
    var defaultOrdinalLevel: Int? {
        return token.defaultOrdinalLevel
    }
    
    var richMessageType: String {
        return Self.richMessageType
	}

    var qqPrefix: String {
        return EthWalletService.qqPrefix
	}

    var isSupportIncreaseFee: Bool {
        return true
    }
    
    var isIncreaseFeeEnabled: Bool {
        return increaseFeeService.isIncreaseFeeEnabled(for: tokenUnicID)
    }
    
    private (set) var blockchainSymbol: String = "ETH"
    private (set) var isDynamicFee: Bool = true
    private (set) var transactionFee: Decimal = 0.0
    private (set) var gasPrice: BigUInt = 0
    private (set) var gasLimit: BigUInt = 0
    private (set) var isWarningGasPrice = false
    
    var isTransactionFeeValid: Bool {
        return ethWallet?.balance ?? 0 > transactionFee
    }
    
    static let transferGas: Decimal = 21000
    static let kvsAddress = "eth:address"
    
    static let walletPath = "m/44'/60'/3'/1"
    static let walletPassword = ""
    
    // MARK: - Dependencies
    weak var accountService: AccountService?
    var apiService: ApiService!
    var erc20ApiService: ERC20ApiService!
    var dialogService: DialogService!
    var increaseFeeService: IncreaseFeeService!
    
    // MARK: - Notifications
    let walletUpdatedNotification: Notification.Name
    let serviceEnabledChanged: Notification.Name
    let transactionFeeUpdated: Notification.Name
    let serviceStateChanged: Notification.Name
    
    // MARK: RichMessageProvider properties
    static let richMessageType = "erc20_transaction"
    var dynamicRichMessageType: String {
        return "\(self.token.symbol.lowercased())_transaction"
    }
    
    // MARK: - Properties
    
    let token: ERC20Token
    @Atomic private(set) var enabled = true
    @Atomic private var subscriptions = Set<AnyCancellable>()
    @Atomic private var initialBalanceCheck = false
    
    // MARK: - State
    @Atomic private (set) var state: WalletServiceState = .notInitiated
    
    private func setState(_ newState: WalletServiceState, silent: Bool = false) {
        guard newState != state else {
            return
        }
        
        state = newState
        
        if !silent {
            NotificationCenter.default.post(
                name: serviceStateChanged,
                object: self,
                userInfo: [AdamantUserInfoKey.WalletService.walletState: state]
            )
        }
    }
    
    private (set) var ethWallet: EthWallet?
    var wallet: WalletAccount? { return ethWallet }
    private var balanceObserver: NSObjectProtocol?
    
    init(token: ERC20Token) {
        self.token = token
        walletUpdatedNotification = Notification.Name("adamant.erc20Wallet.\(token.symbol).walletUpdated")
        serviceEnabledChanged = Notification.Name("adamant.erc20Wallet.\(token.symbol).enabledChanged")
        transactionFeeUpdated = Notification.Name("adamant.erc20Wallet.\(token.symbol).feeUpdated")
        serviceStateChanged = Notification.Name("adamant.erc20Wallet.\(token.symbol).stateChanged")
        
        self.setState(.notInitiated)
        
        // Notifications
        addObservers()
    }
    
    func addObservers() {
        NotificationCenter.default
            .publisher(for: .AdamantAccountService.userLoggedIn, object: nil)
            .receive(on: OperationQueue.main)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &subscriptions)
        
        NotificationCenter.default
            .publisher(for: .AdamantAccountService.accountDataUpdated, object: nil)
            .receive(on: OperationQueue.main)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &subscriptions)
        
        NotificationCenter.default
            .publisher(for: .AdamantAccountService.userLoggedOut, object: nil)
            .receive(on: OperationQueue.main)
            .sink { [weak self] _ in
                self?.ethWallet = nil
                self?.initialBalanceCheck = false
                if let balanceObserver = self?.balanceObserver {
                    NotificationCenter.default.removeObserver(balanceObserver)
                    self?.balanceObserver = nil
                }
            }
            .store(in: &subscriptions)
    }
    
    func update() {
        Task {
            await update()
        }
    }
    
    func update() async {
        guard let wallet = ethWallet else {
            return
        }
        
        switch state {
        case .notInitiated, .updating, .initiationFailed:
            return
            
        case .upToDate:
            break
        }
        
        setState(.updating)
        
        if let balance = try? await getBalance(forAddress: wallet.ethAddress) {
            wallet.isBalanceInitialized = true
            let notification: Notification.Name?
            
            if wallet.balance != balance {
                wallet.balance = balance
                notification = walletUpdatedNotification
                initialBalanceCheck = false
            } else if initialBalanceCheck {
                initialBalanceCheck = false
                notification = walletUpdatedNotification
            } else {
                notification = nil
            }
            
            if let notification = notification {
                NotificationCenter.default.post(name: notification, object: self, userInfo: [AdamantUserInfoKey.WalletService.wallet: wallet])
            }
        }
        
        setState(.upToDate)
        
        await calculateFee()
    }
    
    func calculateFee(for address: EthereumAddress? = nil) async {
        let priceRaw = try? await getGasPrices()
        let gasLimitRaw = try? await getGasLimit(to: address)
        
        var price = priceRaw ?? BigUInt(token.defaultGasPriceGwei).toWei()
        var gasLimit = gasLimitRaw ?? BigUInt(token.defaultGasLimit)
        
        let pricePercent = price * BigUInt(token.reliabilityGasPricePercent) / 100
        let gasLimitPercent = gasLimit * BigUInt(token.reliabilityGasLimitPercent) / 100
        
        price = priceRaw == nil
        ? price
        : price + pricePercent
        
        gasLimit = gasLimitRaw == nil
        ? gasLimit
        : gasLimit + gasLimitPercent

        var newFee = (price * gasLimit).asDecimal(exponent: EthWalletService.currencyExponent)

        newFee = isIncreaseFeeEnabled
        ? newFee * defaultIncreaseFee
        : newFee
        
        guard transactionFee != newFee else { return }
        
        transactionFee = newFee
        let incGasPrice = UInt64(price.asDouble() * defaultIncreaseFee.doubleValue)
                
        gasPrice = isIncreaseFeeEnabled
        ? BigUInt(integerLiteral: incGasPrice)
        : price
        
        isWarningGasPrice = gasPrice >= BigUInt(token.warningGasPriceGwei).toWei()
        self.gasLimit = gasLimit
        
        NotificationCenter.default.post(name: transactionFeeUpdated, object: self, userInfo: nil)
    }
    
    func validate(address: String) -> AddressValidationResult {
        return addressRegex.perfectMatch(with: address) ? .valid : .invalid(description: nil)
    }
    
    func getGasPrices() async throws -> BigUInt {
        try await erc20ApiService.requestWeb3 { web3 in
            try await web3.eth.gasPrice()
        }.get()
    }
    
    func getGasLimit(to address: EthereumAddress?) async throws -> BigUInt {
        guard let ethWallet = ethWallet else {
            throw WalletServiceError.internalError(message: "Can't get ethWallet service", error: nil)
        }
        
        let transaction = try await erc20ApiService.requestERC20(token: token) { erc20 in
            try await erc20.transfer(
                from: ethWallet.ethAddress,
                to: address ?? ethWallet.ethAddress,
                amount: "\(ethWallet.balance)"
            ).transaction
        }.get()
        
        return try await erc20ApiService.requestWeb3 { web3 in
            try await web3.eth.estimateGas(for: transaction)
        }.get()
    }
}

// MARK: - WalletInitiatedWithPassphrase
extension ERC20WalletService: InitiatedWithPassphraseService {
    func initWallet(withPassphrase passphrase: String) async throws -> WalletAccount {
        
        // MARK: 1. Prepare
        setState(.notInitiated)
        
        if enabled {
            enabled = false
            NotificationCenter.default.post(name: serviceEnabledChanged, object: self)
        }
        
        // MARK: 2. Create keys and addresses
        let keystore: BIP32Keystore
        do {
            guard let store = try BIP32Keystore(mnemonics: passphrase, password: EthWalletService.walletPassword, mnemonicsPassword: "", language: .english, prefixPath: EthWalletService.walletPath) else {
                throw WalletServiceError.internalError(message: "ETH Wallet: failed to create Keystore", error: nil)
            }
            
            keystore = store
        } catch {
            throw WalletServiceError.internalError(message: "ETH Wallet: failed to create Keystore", error: error)
        }
        
        erc20ApiService.keystoreManager = .init([keystore])
        
        guard let ethAddress = keystore.addresses?.first else {
            throw WalletServiceError.internalError(message: "ETH Wallet: failed to create Keystore", error: nil)
        }
        
        // MARK: 3. Update
        let eWallet = EthWallet(address: ethAddress.address, ethAddress: ethAddress, keystore: keystore)
        ethWallet = eWallet
        
        if !enabled {
            enabled = true
            NotificationCenter.default.post(name: serviceEnabledChanged, object: self)
        }
        
        self.initialBalanceCheck = true
        self.setState(.upToDate, silent: true)
        Task {
            await update()
        }
        return eWallet
    }
    
    func setInitiationFailed(reason: String) {
        setState(.initiationFailed(reason: reason))
        ethWallet = nil
    }
}

// MARK: - Dependencies
extension ERC20WalletService: SwinjectDependentService {
    @MainActor
    func injectDependencies(from container: Container) {
        accountService = container.resolve(AccountService.self)
        apiService = container.resolve(ApiService.self)
        dialogService = container.resolve(DialogService.self)
        increaseFeeService = container.resolve(IncreaseFeeService.self)
        erc20ApiService = container.resolve(ERC20ApiService.self)
    }
}

// MARK: - Balances & addresses
extension ERC20WalletService {
    func getTransaction(by hash: String) async throws -> EthTransaction {
        let sender = wallet?.address
        let isOutgoing: Bool
        let details: Web3Core.TransactionDetails
        
        // MARK: 1. Transaction details
        do {
            details = try await erc20ApiService.requestWeb3 { web3 in
                try await web3.eth.transactionDetails(hash)
            }.get()
        } catch let error as Web3Error {
            throw error.asWalletServiceError()
        } catch _ as URLError {
            throw WalletServiceError.networkError
        } catch {
            throw WalletServiceError.remoteServiceError(message: "Failed to get transaction")
        }
        
        // MARK: 2. Transaction receipt
        do {
            let receipt = try await erc20ApiService.requestWeb3 { web3 in
                try await web3.eth.transactionReceipt(hash)
            }.get()
            
            // MARK: 3. Check if transaction is delivered
            guard receipt.status == .ok,
                  let blockNumber = details.blockNumber
            else {
                let transaction = details.transaction.asEthTransaction(
                    date: nil,
                    gasUsed: receipt.gasUsed,
                    gasPrice: receipt.effectiveGasPrice,
                    blockNumber: nil,
                    confirmations: nil,
                    receiptStatus: receipt.status,
                    isOutgoing: false
                )
                return transaction
            }
            
            // MARK: 4. Block timestamp & confirmations
            let currentBlock = try await erc20ApiService.requestWeb3 { web3 in
                try await web3.eth.blockNumber()
            }.get()
            
            let block = try await erc20ApiService.requestWeb3 { web3 in
                try await web3.eth.block(by: receipt.blockHash)
            }.get()
            
            guard currentBlock >= blockNumber else {
                throw WalletServiceError.remoteServiceError(
                    message: "ERC20 confirmations calculating error"
                )
            }
            
            let confirmations = currentBlock - blockNumber
            
            let transaction = details.transaction
            
            if let sender = sender {
                isOutgoing = transaction.sender?.address == sender
            } else {
                isOutgoing = false
            }
            
            let ethTransaction = transaction.asEthTransaction(
                date: block.timestamp,
                gasUsed: receipt.gasUsed,
                gasPrice: receipt.effectiveGasPrice,
                blockNumber: String(blockNumber),
                confirmations: String(confirmations),
                receiptStatus: receipt.status,
                isOutgoing: isOutgoing,
                for: self.token
            )
            
            return ethTransaction
        } catch let error as Web3Error {
            switch error {
                // Transaction not delivered yet
            case .inputError, .nodeError:
                let transaction = details.transaction.asEthTransaction(
                    date: nil,
                    gasUsed: nil,
                    gasPrice: nil,
                    blockNumber: nil,
                    confirmations: nil,
                    receiptStatus: TransactionReceipt.TXStatus.notYetProcessed,
                    isOutgoing: false
                )
                return transaction
                
            default:
                throw error
            }
        } catch _ as URLError {
            throw WalletServiceError.networkError
        } catch {
            throw error
        }
    }
    
    func getBalance(address: String) async throws -> Decimal {
        guard let address = EthereumAddress(address) else {
            throw WalletServiceError.internalError(message: "Incorrect address", error: nil)
        }
        
        return try await getBalance(forAddress: address)
    }
    
    func getBalance(forAddress address: EthereumAddress) async throws -> Decimal {
        let exponent = -token.naturalUnits
        
        let balance = try await erc20ApiService.requestERC20(token: token) { erc20 in
            try await erc20.getBalance(account: address)
        }.get()
        
        let value = balance.asDecimal(exponent: exponent)
        return value
    }
    
    func getWalletAddress(byAdamantAddress address: String) async throws -> String {
        let result = try await apiService.get(key: EthWalletService.kvsAddress, sender: address)
            .mapError { $0.asWalletServiceError() }
            .get()
        
        guard let result = result else {
            throw WalletServiceError.walletNotInitiated
        }
        
        return result
    }
}

extension ERC20WalletService {
    func getTransactionsHistory(
        address: String,
        offset: Int = .zero,
        limit: Int = 100
    ) async throws -> [EthTransactionShort] {
        guard let address = self.ethWallet?.address else {
            throw WalletServiceError.internalError(message: "Can't get address", error: nil)
        }
        
        // Request
        let request = "(txto.eq.\(token.contractAddress),or(txfrom.eq.\(address.lowercased()),contract_to.eq.000000000000000000000000\(address.lowercased().replacingOccurrences(of: "0x", with: ""))))"
        
        // MARK: Request
        let txQueryParameters = [
            "limit": String(limit),
            "and": request,
            "offset": String(offset),
            "order": "time.desc"
        ]
        
        var transactions: [EthTransactionShort] = try await erc20ApiService.requestApiCore { core, node in
            await core.sendRequestJson(
                node: node,
                path: EthWalletService.transactionsListApiSubpath,
                method: .get,
                parameters: txQueryParameters,
                encoding: .url
            )
        }.get()
        
        transactions.sort { $0.date.compare($1.date) == .orderedDescending }
        return transactions
    }
}
