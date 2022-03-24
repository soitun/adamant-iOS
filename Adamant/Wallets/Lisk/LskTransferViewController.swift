//
//  LskTransferViewController.swift
//  Adamant
//
//  Created by Anton Boyarkin on 27/11/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka

class LskTransferViewController: TransferViewControllerBase {
    
    // MARK: Dependencies
    
    var chatsProvider: ChatsProvider!
    
    
    // MARK: Properties
    
    private var skipValueChange: Bool = false
    
    
    // MARK: Send
    
    override func sendFunds() {
        let comments: String
        if let row: TextAreaRow = form.rowBy(tag: BaseRows.comments.tag), let text = row.value {
            comments = text
        } else {
            comments = ""
        }
        
        guard let service = service as? LskWalletService, let recipient = recipientAddress, let amount = amount else {
            return
        }
        
        guard let dialogService = dialogService else {
            return
        }
        
        dialogService.showProgress(withMessage: String.adamantLocalized.transfer.transferProcessingMessage, userInteractionEnable: false)
        
        service.createTransaction(recipient: recipient, amount: amount) { [weak self] result in
            guard let vc = self else {
                dialogService.dismissProgress()
                dialogService.showError(withMessage: String.adamantLocalized.sharedErrors.unknownError, error: nil)
                return
            }
            
            switch result {
            case .success(let transaction):
                // MARK: Send LSK transaction
                service.sendTransaction(transaction) { result in
                    switch result {
                    case .success(let hash):
                        // MARK: Send adm report
                        if let reportRecipient = vc.admReportRecipient {
                            self?.reportTransferTo(admAddress: reportRecipient, amount: amount, comments: comments, hash: hash)
                        }
                        service.update()
                        
                        service.getTransaction(by: hash) { result in
                            switch result {
                            case .success(var transaction):
                                vc.dialogService.showSuccess(withMessage: String.adamantLocalized.transfer.transferSuccess)
                                transaction.updateConfirmations(value: service.lastHeight)
                                if let detailsVc = vc.router.get(scene: AdamantScene.Wallets.Lisk.transactionDetails) as? LskTransactionDetailsViewController {
                                    detailsVc.transaction = transaction
                                    detailsVc.service = service
                                    detailsVc.senderName = String.adamantLocalized.transactionDetails.yourAddress
                                    detailsVc.recipientName = self?.recipientName

                                    if comments.count > 0 {
                                        detailsVc.comment = comments
                                    }

                                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: detailsVc)
                                } else {
                                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: nil)
                                }

                            case .failure(let error):
                                if error.message.contains("does not exist") {
                                    vc.dialogService.showSuccess(withMessage: String.adamantLocalized.transfer.transferSuccess)
                                    if let detailsVc = vc.router.get(scene: AdamantScene.Wallets.Lisk.transactionDetails) as? LskTransactionDetailsViewController {
                                        detailsVc.transaction = transaction
                                        detailsVc.service = service
                                        detailsVc.senderName = String.adamantLocalized.transactionDetails.yourAddress
                                        detailsVc.recipientName = self?.recipientName
                                        
                                        if comments.count > 0 {
                                            detailsVc.comment = comments
                                        }
                                        
                                        vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: detailsVc)
                                    } else {
                                        vc.delegate?.transferViewController(vc, didFinishWithTransfer: transaction, detailsViewController: nil)
                                    }
                                } else {
                                    vc.dialogService.showRichError(error: error)
                                    vc.delegate?.transferViewController(vc, didFinishWithTransfer: nil, detailsViewController: nil)
                                }
                            }
                        }
                        
                    case .failure(let error):
                        if error.message.contains("does not meet the minimum remaining balance requirement") {
                            let localizedErrorMessage = NSLocalizedString("TransactionSend.Minimum.Balance", comment: "Transaction send: recipient minimum remaining balance requirement")
                            vc.dialogService.showWarning(withMessage: localizedErrorMessage)
                        }else {
                            vc.dialogService.showRichError(error: error)
                        }
                    }
                }
                
            case .failure(let error):
                dialogService.dismissProgress()
                dialogService.showRichError(error: error)
            }
        }
    }
    
    
    // MARK: Overrides
    
    private var _recipient: String?
    
    override var recipientAddress: String? {
        set {
            _recipient = newValue
            
            if let row: RowOf<String> = form.rowBy(tag: BaseRows.address.tag) {
                row.value = _recipient
                row.updateCell()
            }
        }
        get {
            return _recipient
        }
    }
    
    override func validateRecipient(_ address: String) -> Bool {
        guard let service = service else {
            return false
        }
        
        switch service.validate(address: address) {
        case .valid:
            return true
            
        case .invalid, .system:
            return false
        }
    }
    
    override func recipientRow() -> BaseRow {
        let row = SuffixTextRow() {
            $0.tag = BaseRows.address.tag
            $0.cell.textField.placeholder = String.adamantLocalized.newChat.addressPlaceholder
            $0.cell.textField.keyboardType = UIKeyboardType.alphabet
            
            if let recipient = recipientAddress {
                $0.value = recipient
            }
            
            if recipientIsReadonly {
                $0.disabled = true
                $0.cell.textField.isEnabled = false
            }
            }.cellUpdate { (cell, row) in
                if let text = cell.textField.text {
                    cell.textField.text = text
                }
            }.onChange { [weak self] row in
                if let skip = self?.skipValueChange, skip {
                    self?.skipValueChange = false
                    return
                }
                
                if let text = row.value {
                    self?.skipValueChange = true
                    
                    DispatchQueue.main.async {
                        row.value = text
                        row.updateCell()
                    }
                }
                
                self?.validateForm()
            }.onCellSelection { [weak self] (cell, row) in
                if let recipient = self?.recipientAddress {
                    let text = recipient
                    self?.shareValue(text, from: cell)
                }
            }
        
        return row
    }
    
    override func handleRawAddress(_ address: String) -> Bool {
        guard let service = service else {
            return false
        }
        
        let parsedAddress: String
        if address.hasPrefix("lisk:") || address.hasPrefix("lsk:"), let firstIndex = address.firstIndex(of: ":") {
            let index = address.index(firstIndex, offsetBy: 1)
            parsedAddress = String(address[index...])
        } else {
            parsedAddress = address
        }
        
        switch service.validate(address: parsedAddress) {
        case .valid:
            if let row: RowOf<String> = form.rowBy(tag: BaseRows.address.tag) {
                row.value = parsedAddress
                row.updateCell()
            }
            
            return true
            
        default:
            return false
        }
    }
    
    func reportTransferTo(admAddress: String, amount: Decimal, comments: String, hash: String) {
        let payload = RichMessageTransfer(type: LskWalletService.richMessageType, amount: amount, hash: hash, comments: comments)
        
        let message = AdamantMessage.richMessage(payload: payload)
        chatsProvider.chatPositon.removeValue(forKey: admAddress)
        chatsProvider.sendMessage(message, recipientId: admAddress) { [weak self] result in
            if case .failure(let error) = result {
                self?.dialogService.showRichError(error: error)
            }
        }
    }
    
    override func defaultSceneTitle() -> String? {
        return String.adamantLocalized.sendLsk
    }
    
    
    // MARK: - Tools
    
    func shareValue(_ value: String, from: UIView) {
        dialogService.presentShareAlertFor(string: value, types: [.copyToPasteboard, .share], excludedActivityTypes: nil, animated: true, from: from) { [weak self] in
            guard let tableView = self?.tableView else {
                return
            }
            
            if let indexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}
