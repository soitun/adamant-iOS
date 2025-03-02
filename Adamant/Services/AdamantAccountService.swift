//
//  AdamantAccountService.swift
//  Adamant
//
//  Created by Anokhov Pavel on 07.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import UIKit
import Combine
import CommonKit

final class AdamantAccountService: AccountService, @unchecked Sendable {
    
    // MARK: Dependencies
    
    private let apiService: AdamantApiServiceProtocol
    private let adamantCore: AdamantCore
    private let dialogService: DialogService
    private let securedStore: SecuredStore
    private let walletServiceCompose: WalletServiceCompose
    private let currencyInfoService: InfoServiceProtocol

    weak var notificationsService: NotificationsService?
    weak var pushNotificationsTokenService: PushNotificationsTokenService?
    weak var visibleWalletService: VisibleWalletsService?
    
    // MARK: Properties
    
    @Atomic private(set) var state: AccountServiceState = .notLogged
    @Atomic private(set) var isBalanceExpired = true
    @Atomic private(set) var account: AdamantAccount?
    @Atomic private(set) var keypair: Keypair?
    @Atomic private var passphrase: String?
    @Atomic private(set) var hasStayInAccount = false
    @Atomic private(set) var useBiometry = false
    @Atomic private var previousAppState: UIApplication.State?
    @Atomic private var subscriptions = Set<AnyCancellable>()
    @Atomic private var balanceInvalidationSubscription: AnyCancellable?
    
    init(
        apiService: AdamantApiServiceProtocol,
        adamantCore: AdamantCore,
        dialogService: DialogService,
        securedStore: SecuredStore,
        walletServiceCompose: WalletServiceCompose,
        currencyInfoService: InfoServiceProtocol,
        connection: AnyObservable<Bool>
    ) {
        self.apiService = apiService
        self.adamantCore = adamantCore
        self.dialogService = dialogService
        self.securedStore = securedStore
        self.walletServiceCompose = walletServiceCompose
        self.currencyInfoService = currencyInfoService
        
        NotificationCenter.default.addObserver(forName: .AdamantAccountService.forceUpdateBalance, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.update()
        }
        
        NotificationCenter.default.addObserver(forName: .AdamantAccountService.forceUpdateAllBalances, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.updateAll()
        }
        
        NotificationCenter.default
            .notifications(named: UIApplication.didBecomeActiveNotification, object: nil)
            .sink { @MainActor [weak self] _ in
                guard self?.previousAppState == .background else { return }
                self?.previousAppState = .active
                self?.update()
            }
            .store(in: &subscriptions)
        
        NotificationCenter.default
            .notifications(named: UIApplication.willResignActiveNotification, object: nil)
            .sink { @MainActor [weak self] _ in
                self?.previousAppState = .background
            }
            .store(in: &subscriptions)
        
        connection.filter { $0 }.sink { [weak self] _ in
            self?.update()
        }.store(in: &subscriptions)
        
        setupSecuredStore()
    }
}

// MARK: - Saved data
extension AdamantAccountService {
    func setStayLoggedIn(pin: String, completion: @escaping @Sendable (AccountServiceResult) -> Void) {
        guard let account = account, let keypair = keypair else {
            completion(.failure(.userNotLogged))
            return
        }
        
        if hasStayInAccount {
            completion(.failure(.internalError(message: "Already has account", error: nil)))
            return
        }
        
        securedStore.set(pin, for: .pin)
        
        if let passphrase = passphrase {
            securedStore.set(passphrase, for: .passphrase)
        } else {
            securedStore.set(keypair.publicKey, for: .publicKey)
            securedStore.set(keypair.privateKey, for: .privateKey)
        }
        
        hasStayInAccount = true
        NotificationCenter.default.post(name: Notification.Name.AdamantAccountService.stayInChanged, object: self, userInfo: [AdamantUserInfoKey.AccountService.newStayInState : true])
        completion(.success(account: account, alert: nil))
    }
    
    func validatePin(_ pin: String) -> Bool {
        guard let savedPin = securedStore.get(.pin) else {
            return false
        }
        
        return pin == savedPin
    }
    
    private func getSavedKeypair() -> Keypair? {
        if let publicKey = securedStore.get(.publicKey), let privateKey = securedStore.get(.privateKey) {
            return Keypair(publicKey: publicKey, privateKey: privateKey)
        }
        
        return nil
    }
    
    private func getSavedPassphrase() -> String? {
        return securedStore.get(.passphrase)
    }
    
    func dropSavedAccount() {
        useBiometry = false
        isBalanceExpired = true
        pushNotificationsTokenService?.removeCurrentToken()
        balanceInvalidationSubscription = nil
        Key.allCases.forEach(securedStore.remove)
        
        hasStayInAccount = false
        NotificationCenter.default.post(name: Notification.Name.AdamantAccountService.stayInChanged, object: self, userInfo: [AdamantUserInfoKey.AccountService.newStayInState : false])
        
        Task { @MainActor in notificationsService?.setNotificationsMode(.disabled, completion: nil) }
    }
    
    private func markBalanceAsFresh() {
        isBalanceExpired = false
        
        balanceInvalidationSubscription = Task { [weak self] in
            try await Task.sleep(
                interval: AdmWalletService.balanceLifetime,
                pauseInBackground: true
            )
            
            guard let self else { return }
            isBalanceExpired = true
            NotificationCenter.default.post(
                name: .AdamantAccountService.accountDataUpdated,
                object: self
            )
        }.eraseToAnyCancellable()
    }
    
    private func setupSecuredStore() {
        if securedStore.get(.passphrase) != nil {
            hasStayInAccount = true
            useBiometry = securedStore.get(.useBiometry) != nil
        } else if securedStore.get(.publicKey) != nil,
            securedStore.get(.privateKey) != nil,
            securedStore.get(.pin) != nil {
            hasStayInAccount = true
            
            useBiometry = securedStore.get(.useBiometry) != nil
        } else {
            hasStayInAccount = false
            useBiometry = false
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name.SecuredStore.securedStorePurged, object: securedStore, queue: OperationQueue.main) { [weak self] notification in
            guard let store = notification.object as? SecuredStore else {
                return
            }
            
            if store.get(.passphrase) != nil {
                self?.hasStayInAccount = true
                self?.useBiometry = store.get(.useBiometry) != nil
            } else {
                self?.hasStayInAccount = false
                self?.useBiometry = false
            }
        }
    }
    
    func updateUseBiometry(_ newValue: Bool) {
        $useBiometry.mutate {
            $0 = newValue && hasStayInAccount
            
            if $0 {
                securedStore.set(String($0), for: .useBiometry)
            } else {
                securedStore.remove(.useBiometry)
            }
        }
    }
}

// MARK: - AccountService
extension AdamantAccountService {
    // MARK: Update logged account info
    func update() {
        self.update(nil)
    }
    
    func updateAll() {
        update(nil, updateOnlyVisible: false)
    }
    
    func update(_ completion: (@Sendable (AccountServiceResult) -> Void)?) {
        update(completion, updateOnlyVisible: true)
    }
    
    func update(_ completion: (@Sendable (AccountServiceResult) -> Void)?, updateOnlyVisible: Bool) {
        switch state {
        case .notLogged, .isLoggingIn, .updating:
            return
            
        case .loggedIn:
            break
        }
        
        let prevState = state
        state = .updating
        
        guard let loggedAccount = account, let publicKey = loggedAccount.publicKey else {
            return
        }
        
        let wallets = walletServiceCompose.getWallets().map { $0.core }
        
        Task { @Sendable in
            let result = await apiService.getAccount(byPublicKey: publicKey)
            
            switch result {
            case .success(let account):
                guard let acc = self.account, acc.address == account.address else {
                    // User has logged out, we not interested anymore
                    state = .notLogged
                    return
                }
                
                markBalanceAsFresh()
                self.account = account
                
                NotificationCenter.default.post(
                    name: .AdamantAccountService.accountDataUpdated,
                    object: self
                )
                
                state = .loggedIn
                completion?(.success(account: account, alert: nil))
                
                if let adm = wallets.first(where: { $0 is AdmWalletService }) {
                    adm.update()
                }
                
            case .failure(let error):
                completion?(.failure(.apiError(error: error)))
                state = prevState
            }
        }
        
        if updateOnlyVisible {
            for wallet in wallets.filter({ !($0 is AdmWalletService) }) where !(visibleWalletService?.isInvisible(wallet) ?? false) {
                wallet.update()
            }
        } else {
            for wallet in wallets.filter({ !($0 is AdmWalletService) }) {
                wallet.update()
            }
        }
    }
}

// MARK: - Log In
extension AdamantAccountService {
    // MARK: Passphrase
    @MainActor
    func loginWith(passphrase: String) async throws -> AccountServiceResult {
        guard AdamantUtilities.validateAdamantPassphrase(passphrase: passphrase) else {
            throw AccountServiceError.invalidPassphrase
        }
        
        guard let keypair = adamantCore.createKeypairFor(passphrase: passphrase) else {
            throw AccountServiceError.internalError(message: "Failed to generate keypair for passphrase", error: nil)
        }
        
        let account = try await loginWith(keypair: keypair)
        
        // MARK: Drop saved accs
        if let storedPassphrase = self.getSavedPassphrase(),
           storedPassphrase != passphrase {
            dropSavedAccount()
        }
        
        if let storedKeypair = self.getSavedKeypair(),
           storedKeypair != self.keypair {
            dropSavedAccount()
        }
        
        // Update and initiate wallet services
        self.passphrase = passphrase
        
        _ = await initWallets()
        
        return .success(account: account, alert: nil)
    }
    
    // MARK: Pincode
    func loginWith(pincode: String) async throws -> AccountServiceResult {
        guard let storePin = securedStore.get(.pin) else {
            throw AccountServiceError.invalidPassphrase
        }
        
        guard storePin == pincode else {
            throw AccountServiceError.invalidPassphrase
        }
        
        return try await loginWithStoredAccount()
    }
    
    // MARK: Biometry
    @MainActor
    func loginWithStoredAccount() async throws -> AccountServiceResult {
        if let passphrase = getSavedPassphrase() {
            let account = try await loginWith(passphrase: passphrase)
            return account
        }
        
        if let keypair = getSavedKeypair() {
            let account = try await loginWith(keypair: keypair)
            
            let alert: (title: String, message: String)?
            if securedStore.get(.showedV12) != nil {
                alert = nil
            } else {
                securedStore.set("1", for: .showedV12)
                alert = (title: String.adamant.accountService.updateAlertTitleV12,
                         message: String.adamant.accountService.updateAlertMessageV12)
            }
            
            for wallet in walletServiceCompose.getWallets() {
                wallet.core.setInitiationFailed(reason: .adamant.accountService.reloginToInitiateWallets)
            }
            
            return .success(account: account, alert: alert)
        }
        
        throw AccountServiceError.invalidPassphrase
    }
    
    // MARK: Keypair
    private func loginWith(keypair: Keypair) async throws -> AdamantAccount {
        switch state {
        case .isLoggingIn:
            throw AccountServiceError.internalError(message: "Service is busy", error: nil)
        case .updating:
            fallthrough
            
        // Logout first
        case .loggedIn:
            logout()
            
        // Go login
        case .notLogged:
            break
        }
        
        state = .isLoggingIn
        
        do {
            let account = try await apiService.getAccount(byPublicKey: keypair.publicKey).get()
            self.account = account
            self.keypair = keypair
            markBalanceAsFresh()
            
            let userInfo = [AdamantUserInfoKey.AccountService.loggedAccountAddress: account.address]
            
            NotificationCenter.default.post(
                name: Notification.Name.AdamantAccountService.userLoggedIn,
                object: self,
                userInfo: userInfo
            )
            
            self.state = .loggedIn
            return account
        } catch let error as ApiServiceError {
            self.state = .notLogged
            
            switch error {
            case .accountNotFound:
                throw AccountServiceError.wrongPassphrase
                
            default:
                throw AccountServiceError.apiError(error: error)
            }
        } catch {
            throw AccountServiceError.internalError(message: error.localizedDescription, error: error)
        }
    }
    
    func reloadWallets() {
        Task {
            _ = await initWallets()
        }
    }
    
    func initWallets() async -> [WalletAccount?] {
        guard let passphrase = passphrase else {
            print("No passphrase found")
            return []
        }
        
        return await withTaskGroup(of: WalletAccount?.self) { group in
            for wallet in walletServiceCompose.getWallets() {
                group.addTask {
                    let result = try? await wallet.core.initWallet(
                        withPassphrase: passphrase
                    )
                    return result
                }
            }
            
            var wallets: [WalletAccount?] = []
            
            for await wallet in group {
                wallets.append(wallet)
            }

            return wallets
        }
    }
}

// MARK: - Log Out
extension AdamantAccountService {
    func logout() {
        if account != nil {
            NotificationCenter.default.post(name: Notification.Name.AdamantAccountService.userWillLogOut, object: self)
        }
        
        dropSavedAccount()
        
        let wasLogged = account != nil
        account = nil
        keypair = nil
        passphrase = nil
        state = .notLogged
        
        guard wasLogged else { return }
        NotificationCenter.default.post(name: .AdamantAccountService.userLoggedOut, object: self)
    }
}

private enum Key: CaseIterable {
    case publicKey
    case privateKey
    case pin
    case useBiometry
    case passphrase
    case showedV12
    case blockListKey
    case removedMessages
    
    var stringValue: String {
        switch self {
        case .publicKey: return StoreKey.accountService.publicKey
        case .privateKey: return StoreKey.accountService.privateKey
        case .pin: return StoreKey.accountService.pin
        case .useBiometry: return StoreKey.accountService.useBiometry
        case .passphrase: return StoreKey.accountService.passphrase
        case .showedV12: return StoreKey.accountService.showedV12
        case .blockListKey: return StoreKey.accountService.blockList
        case .removedMessages: return StoreKey.accountService.removedMessages
        }
    }
}

private extension SecuredStore {
    func set(_ value: String, for key: Key) {
        set(value, for: key.stringValue)
    }
    
    func get(_ key: Key) -> String? {
        return get(key.stringValue)
    }
    
    func remove(_ key: Key) {
        remove(key.stringValue)
    }
}
