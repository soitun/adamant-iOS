//
//  TransactionDetailsViewControllerBase.swift
//  Adamant
//
//  Created by Anton Boyarkin on 25/06/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka
import SafariServices
import CommonKit

// MARK: - TransactionStatus UI
private extension TransactionStatus {
    var color: UIColor {
        switch self {
        case .failed: return .adamant.warning
        case .notInitiated, .inconsistent, .pending, .registered: return .adamant.attention
        case .success: return .adamant.success
        }
    }
    
    var descriptionLocalized: String? {
        switch self {
        case .inconsistent(let reason):
            return reason.localized
        default:
            return nil
        }
    }
}

// MARK: - Localization
extension String.adamant {
    enum transactionDetails {
        static var title: String {
            String.localized("TransactionDetailsScene.Title", comment: "Transaction details: scene title")
        }
        static var yourAddress: String {
            String.adamant.notifications.yourAddress
        }
        static var requestingDataProgressMessage: String {
            String.localized("TransactionDetailsScene.RequestingData", comment: "Transaction details: 'Requesting Data' progress message.")
        }
    }
}

extension String.adamant.alert {
    static var exportUrlButton: String { String.localized("TransactionDetailsScene.Share.URL", comment: "Export transaction: 'Share transaction URL' button")
    }
    static var exportSummaryButton: String { String.localized("TransactionDetailsScene.Share.Summary", comment: "Export transaction: 'Share transaction summary' button")
    }
}

class TransactionDetailsViewControllerBase: FormViewController {
    // MARK: - Rows
    enum Rows {
        case transactionNumber
        case from
        case to
        case date
        case amount
        case fee
        case confirmations
        case block
        case status
        case openInExplorer
        case openChat
        case comment
        case historyFiat
        case currentFiat
        case inconsistentReason
        case txBlockchainComment
        
        var tag: String {
            switch self {
            case .transactionNumber: return "id"
            case .from: return "from"
            case .to: return "to"
            case .date: return "date"
            case .amount: return "amount"
            case .fee: return "fee"
            case .confirmations: return "confirmations"
            case .block: return "block"
            case .status: return "status"
            case .openInExplorer: return "openInExplorer"
            case .openChat: return "openChat"
            case .comment: return "comment"
            case .historyFiat: return "hfiat"
            case .currentFiat: return "cfiat"
            case .inconsistentReason: return "incReason"
            case .txBlockchainComment: return "data"
            }
        }
        
        var localized: String {
            switch self {
            case .transactionNumber: return .localized("TransactionDetailsScene.Row.Id", comment: "Transaction details: Id row.")
            case .from: return .localized("TransactionDetailsScene.Row.From", comment: "Transaction details: sender row.")
            case .to: return .localized("TransactionDetailsScene.Row.To", comment: "Transaction details: recipient row.")
            case .date: return .localized("TransactionDetailsScene.Row.Date", comment: "Transaction details: date row.")
            case .amount: return .localized("TransactionDetailsScene.Row.Amount", comment: "Transaction details: amount row.")
            case .fee: return .localized("TransactionDetailsScene.Row.Fee", comment: "Transaction details: fee row.")
            case .confirmations: return .localized("TransactionDetailsScene.Row.Confirmations", comment: "Transaction details: confirmations row.")
            case .block: return .localized("TransactionDetailsScene.Row.Block", comment: "Transaction details: Block id row.")
            case .status: return .localized("TransactionDetailsScene.Row.Status", comment: "Transaction details: Transaction delivery status.")
            case .openInExplorer: return .localized("TransactionDetailsScene.Row.Explorer", comment: "Transaction details: 'Open transaction in explorer' row.")
            case .openChat: return ""
            case .comment: return ""
            case .historyFiat: return .localized("TransactionDetailsScene.Row.HistoryFiat", comment: "Transaction details: fiat value at the time")
            case .currentFiat: return .localized("TransactionDetailsScene.Row.CurrentFiat", comment: "Transaction details: current fiat value")
            case .inconsistentReason:
                return .localized("TransactionStatus.Inconsistent.Reason.Title", comment: "Transaction status: inconsistent reason title")
            case .txBlockchainComment:
                return
                    .localized("TransactionStatus.Inconsistent.RecordData.Title", comment: "Transaction details: Tx data record")
            }
        }
        
        var image: UIImage? {
            switch self {
            case .openInExplorer: return .asset(named: "row_explorer")
            case .openChat: return .asset(named: "row_chat")
                
            default: return nil
            }
        }
    }
    
    enum Sections {
        case details
        case comment
        case actions
        case inconsistentReason
        
        var localized: String {
            switch self {
            case .details: return ""
            case .comment: return .localized("TransactionDetailsScene.Section.Comment", comment: "Transaction details: 'Comments' section")
            case .actions: return .localized("TransactionDetailsScene.Section.Actions", comment: "Transaction details: 'Actions' section")
            case .inconsistentReason:
                return .localized("TransactionStatus.Inconsistent.Reason.Title", comment: "Transaction status: inconsistent reason title")
            }
        }
        
        var tag: String {
            switch self {
            case .details: return "details"
            case .comment: return "comment"
            case .actions: return "actions"
            case .inconsistentReason: return "inconsistentReason"
            }
        }
    }
    
    // MARK: - Dependencies
    
    let dialogService: DialogService
    let currencyInfo: InfoServiceProtocol
    let addressBookService: AddressBookService
    let accountService: AccountService
    let walletService: WalletService?
    let languageService: LanguageStorageProtocol
    
    // MARK: - Properties
    
    var showTxBlockchainComment: Bool {
        false
    }
    
    var transaction: TransactionDetails? {
        didSet {
            if !isFiatSet {
                self.updateFiat()
            }
            
            guard let id = transaction?.txId else { return }
            
            walletService?.core.updateStatus(
                for: id,
                status: transaction?.transactionStatus
            )
        }
    }
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: languageService.getLanguage().locale)
        return dateFormatter
    }()
    
    static let awaitingValueString = TransactionStatus.notInitiated.localized
    
    private lazy var currencyFormatter: NumberFormatter = {
        return AdamantBalanceFormat.currencyFormatter(for: .full, currencySymbol: currencySymbol)
    }()

    var feeFormatter: NumberFormatter {
        return currencyFormatter
    }
    
    private lazy var fiatFormatter: NumberFormatter = {
        return AdamantBalanceFormat.fiatFormatter(for: currencyInfo.currentCurrency)
    }()
    
    private var isFiatSet = false
    
    var feeCurrencySymbol: String? {
        currencySymbol
    }
    
    var transactionStatus: TransactionStatus? {
        guard let richTransaction = richTransaction,
              let status = richTransaction.transactionStatus
        else {
            return transaction?.transactionStatus
        }
        
        return status
    }
    
    var refreshTask: Task<(), Never>?
    
    var richTransaction: RichMessageTransaction?
    
    var senderId: String? {
        didSet {
            senderName = getName(by: senderId)
        }
    }
    
    var recipientId: String? {
        didSet {
            recipientName = getName(by: recipientId)
        }
    }
    
    var valueAtTimeTxn: String? {
        didSet {
            updateValueAtTimeRowValue()
        }
    }
    
    var feeAtTimeTxn: String? {
        didSet {
            updateFeeAtTimeRowValue()
        }
    }
    
    // MARK: - Lifecycle
    
    init(
        dialogService: DialogService,
        currencyInfo: InfoServiceProtocol,
        addressBookService: AddressBookService,
        accountService: AccountService,
        walletService: WalletService?,
        languageService: LanguageStorageProtocol
    ) {
        self.dialogService = dialogService
        self.currencyInfo = currencyInfo
        self.addressBookService = addressBookService
        self.accountService = accountService
        self.walletService = walletService
        self.languageService = languageService
        
        super.init(style: .grouped)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.largeTitleDisplayMode = .never // some glitches, again
        navigationItem.title = String.adamant.transactionDetails.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
        navigationOptions = RowNavigationOptions.Disabled
        
        // MARK: - Transfer section
        let detailsSection = Section {
            $0.tag = Sections.details.tag
        }
            
        // MARK: Transaction number
        let idRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.transactionNumber.tag
            $0.title = Rows.transactionNumber.localized
            
            if let value = transaction?.txId {
                $0.value = value
            } else {
                $0.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
            
            $0.cell.detailTextLabel?.textAlignment = .right
            $0.cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let value = self?.transaction?.txId {
                row.value = value
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
        
        detailsSection.append(idRow)
        
        // MARK: Sender
        let senderRow = DoubleDetailsRow { [weak self] in
            $0.disabled = true
            $0.tag = Rows.from.tag
            $0.cell.titleLabel.text = Rows.from.localized
            
            if let transaction = self?.transaction {
                if let name = self?.senderName {
                    $0.value = DoubleDetail(first: name, second: transaction.senderAddress)
                } else {
                    $0.value = transaction.senderAddress.isEmpty
                    ? DoubleDetail(first: Self.awaitingValueString, second: nil)
                    : DoubleDetail(first: transaction.senderAddress, second: nil)
                }
            } else {
                $0.value = nil
            }
            
            let height = self?.senderName != nil ? DoubleDetailsTableViewCell.fullHeight : DoubleDetailsTableViewCell.compactHeight
            $0.cell.height = { height }
            $0.cell.secondDetailsLabel?.textAlignment = .right
            $0.cell.detailsLabel?.textAlignment = .right
            $0.cell.secondDetailsLabel?.lineBreakMode = .byTruncatingMiddle
            $0.cell.detailsLabel?.lineBreakMode = .byTruncatingMiddle
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            guard let value = row.value else {
                return
            }
            
            let text: String
            if let address = value.second {
                text = address
            } else {
                text = value.first
            }
            
            self?.shareValue(text, from: cell)
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let transaction = self?.transaction {
                if let name = self?.senderName {
                    row.value = DoubleDetail(first: name, second: transaction.senderAddress)
                } else {
                    row.value = transaction.senderAddress.isEmpty
                    ? DoubleDetail(first: Self.awaitingValueString, second: nil)
                    : DoubleDetail(first: transaction.senderAddress, second: nil)
                }
            } else {
                row.value = nil
            }
        }
            
        detailsSection.append(senderRow)
        
        // MARK: Recipient
        let recipientRow = DoubleDetailsRow { [weak self] in
            $0.disabled = true
            $0.tag = Rows.to.tag
            $0.cell.titleLabel.text = Rows.to.localized
            
            if let transaction = self?.transaction {
                if let recipientName = self?.recipientName?.checkAndReplaceSystemWallets() {
                    $0.value = DoubleDetail(first: recipientName, second: transaction.recipientAddress)
                } else {
                    $0.value = DoubleDetail(first: transaction.recipientAddress, second: nil)
                    if transaction.recipientAddress.isEmpty {
                        $0.value = DoubleDetail(first: TransactionDetailsViewControllerBase.awaitingValueString, second: nil)
                    }
                }
            } else {
                $0.value = nil
            }
            
            let height = self?.recipientName != nil ? DoubleDetailsTableViewCell.fullHeight : DoubleDetailsTableViewCell.compactHeight
            $0.cell.height = { height }
            $0.cell.secondDetailsLabel?.textAlignment = .right
            $0.cell.detailsLabel?.textAlignment = .right
            $0.cell.secondDetailsLabel?.lineBreakMode = .byTruncatingMiddle
            $0.cell.detailsLabel?.lineBreakMode = .byTruncatingMiddle
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            guard let value = row.value else {
                return
            }
            
            let text: String
            if let address = value.second {
                text = address
            } else {
                text = value.first
            }
            
            self?.shareValue(text, from: cell)
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            
            if let transaction = self?.transaction {
                if let recipientName = self?.recipientName?.checkAndReplaceSystemWallets() {
                    row.value = DoubleDetail(first: recipientName, second: transaction.recipientAddress)
                } else {
                    row.value = DoubleDetail(first: transaction.recipientAddress, second: nil)
                    if transaction.recipientAddress.isEmpty {
                        row.value = DoubleDetail(first: TransactionDetailsViewControllerBase.awaitingValueString, second: nil)
                    }
                }
            } else {
                row.value = nil
            }
        }
        
        detailsSection.append(recipientRow)
        
        // MARK: Date
        let dateRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.date.tag
            $0.title = Rows.date.localized
            
            if let raw = transaction?.dateValue {
                $0.value = dateFormatter.string(from: raw)
            } else {
                $0.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, _) in
            if let value = self?.transaction?.dateValue {
                let text = value.humanizedDateTimeFull()
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let raw = self?.transaction?.dateValue, let value = self?.dateFormatter.string(from: raw) {
                row.value = value
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
            
        detailsSection.append(dateRow)
        
        // MARK: Amount
        let amountRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.amount.tag
            $0.title = Rows.amount.localized
            if let value = transaction?.amountValue {
                $0.value = currencyFormatter.string(from: value)
            } else {
                $0.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let value = row.value {
                self?.shareValue(value, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let value = self?.transaction?.amountValue, let formatter = self?.currencyFormatter {
                row.value = formatter.string(from: value)
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
            
        detailsSection.append(amountRow)
        
        // MARK: Fee
        let feeRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.fee.tag
            $0.title = Rows.fee.localized
            $0.value = getFeeValue()
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let value = row.value {
                self?.shareValue(value, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            row.value = self?.getFeeValue()
        }
            
        detailsSection.append(feeRow)
        
        // MARK: Confirmations
        let confirmationsRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.confirmations.tag
            $0.title = Rows.confirmations.localized
            
            if let value = transaction?.confirmationsValue, value != "0" {
                $0.value = value
            } else {
                $0.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
            
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let value = self?.transaction?.confirmationsValue, value != "0" {
                row.value = value
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
            
        detailsSection.append(confirmationsRow)
        
        // MARK: Block
        let blockRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.block.tag
            $0.title = Rows.block.localized
            
            if let value = transaction?.blockValue,
               !value.isEmpty {
                $0.value = value
            } else {
                $0.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
            $0.cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let value = self?.transaction?.blockValue,
               !value.isEmpty {
                row.value = value
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
            
        detailsSection.append(blockRow)
            
        // MARK: Status
        let statusRow = LabelRow {
            $0.tag = Rows.status.tag
            $0.title = Rows.status.localized
            $0.value = transactionStatus?.localized
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
			cell.detailTextLabel?.textColor = self?.transactionStatus?.color ?? UIColor.adamant.textColor
            
            if let value = self?.transactionStatus?.localized,
               !value.isEmpty {
                row.value = value
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
        
        detailsSection.append(statusRow)
        
        // MARK: Current Fiat
        let currentFiatRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.currentFiat.tag
            $0.title = Rows.currentFiat.localized
            
            if let amount = transaction?.amountValue, let symbol = currencySymbol, let rate = currencyInfo.getRate(for: symbol) {
                let value = amount * rate
                $0.value = fiatFormatter.string(from: value)
            } else {
                $0.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let amount = self?.transaction?.amountValue,
               let symbol = self?.currencySymbol,
               let rate = self?.currencyInfo.getRate(for: symbol),
               let value = self?.fiatFormatter.string(from: amount * rate) {
                row.value = value
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
        
        detailsSection.append(currentFiatRow)
        
        form.append(detailsSection)
        
        // MARK: History Fiat
        let fiatRow = LabelRow {
            $0.disabled = true
            $0.tag = Rows.historyFiat.tag
            $0.title = Rows.historyFiat.localized
            
            $0.value = TransactionDetailsViewControllerBase.awaitingValueString
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { (cell, _) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }
        
        detailsSection.append(fiatRow)
        
        // MARK: Tx blockchain comment
        let txBlockchainComment = LabelRow {
            $0.disabled = true
            $0.tag = Rows.txBlockchainComment.tag
            $0.title = Rows.txBlockchainComment.localized
            
            if let value = transaction?.txBlockchainComment {
                $0.value = value
            } else {
                $0.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
            
            $0.cell.detailTextLabel?.textAlignment = .right
            $0.cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
            
            $0.hidden = Condition.function([], { [weak self] _ -> Bool in
                guard let value = self?.transaction?.txBlockchainComment else {
                    return false
                }
                
                if value.isEmpty {
                    return true
                }
                return false
            })
            
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }.cellUpdate { [weak self] (cell, row) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            if let value = self?.transaction?.txBlockchainComment {
                row.value = value
            } else {
                row.value = TransactionDetailsViewControllerBase.awaitingValueString
            }
        }
        
        if showTxBlockchainComment {
            detailsSection.append(txBlockchainComment)
        }
        
        // MARK: Comments section
        
        if let comment = comment {
            let commentSection = Section(Sections.comment.localized) {
                $0.tag = Sections.comment.tag
            }
            
            let row = TextAreaRow(Rows.comment.tag) {
                $0.textAreaHeight = .dynamic(initialTextViewHeight: 44)
                $0.value = comment
            }.cellSetup { (cell, _) in
                cell.selectionStyle = .gray
                cell.textLabel?.textColor = UIColor.adamant.textColor
            }.cellUpdate { (cell, _) in
                cell.textView?.backgroundColor = UIColor.clear
                cell.textView.isSelectable = false
                cell.textView.isEditable = false
            }.onCellSelection { [weak self] (cell, row) in
                if let text = row.value {
                    self?.shareValue(text, from: cell)
                }
            }
            
            commentSection.append(row)
            
            form.append(commentSection)
        }
        
        // MARK: Inconsistent Reason
        
        let inconsistentReasonSection = Section(Sections.inconsistentReason.localized) {
            $0.tag = Sections.inconsistentReason.tag
            $0.hidden = Condition.function([], { [weak self] _ -> Bool in
                if case .inconsistent = self?.transactionStatus {
                    return false
                }
                return true
            })
        }
        
        let inconsistentReasonRow = TextAreaRow(Rows.inconsistentReason.tag) {
            $0.textAreaHeight = .dynamic(initialTextViewHeight: 44)
            $0.value = transactionStatus?.descriptionLocalized
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.cellUpdate { [weak self] (cell, row) in
            cell.textView.backgroundColor = UIColor.clear
            cell.textView.isSelectable = false
            cell.textView.isEditable = false
            row.value = self?.transactionStatus?.descriptionLocalized
        }.onCellSelection { [weak self] (cell, row) in
            if let text = row.value {
                self?.shareValue(text, from: cell)
            }
        }
        
        inconsistentReasonSection.append(inconsistentReasonRow)
        form.append(inconsistentReasonSection)
        
        // MARK: Actions section
        
        let actionsSection = Section(Sections.actions.localized) {
            $0.tag = Sections.actions.tag
            $0.hidden = Condition.function([], { [weak self] _ -> Bool in
                return self?.transaction == nil
            })
        }
            
        // MARK: Open in explorer
        let explorerRow = LabelRow(Rows.openInExplorer.tag) {
            $0.hidden = Condition.function([], { [weak self] _ -> Bool in
                if let transaction = self?.transaction {
                    return self?.explorerUrl(for: transaction) == nil
                } else {
                    return true
                }
            })
            
            $0.title = Rows.openInExplorer.localized
            $0.cell.imageView?.image = Rows.openInExplorer.image
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
            cell.textLabel?.textColor = UIColor.adamant.textColor
        }.cellUpdate { (cell, _) in
            cell.textLabel?.textColor = UIColor.adamant.textColor
            cell.accessoryType = .disclosureIndicator
        }.onCellSelection { [weak self] (_, _) in
            guard let transaction = self?.transaction, let url = self?.explorerUrl(for: transaction) else {
                return
            }
            
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor.adamant.primary
            safari.modalPresentationStyle = .overFullScreen
            self?.present(safari, animated: true, completion: nil)
        }
        
        actionsSection.append(explorerRow)
        
        form.append(actionsSection)
        
        // Get fiat value
        self.updateFiat()
        
        setColors()
        
        checkAddressesIfNeeded()
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    func updateFiat() {
        guard let date = transaction?.dateValue,
              let currencySymbol = currencySymbol,
              let amount = transaction?.amountValue
        else { return }
        
        let currentFiat = currencyInfo.currentCurrency.rawValue
        
        Task {
            var tickers = try await currencyInfo.getHistory(
                for: currencySymbol,
                date: date
            ).get()
            
            isFiatSet = true
            
            guard
                var ticker = tickers[.init(
                    crypto: currencySymbol,
                    fiat: currentFiat
                )]
            else { return }
            
            let totalFiat = amount * ticker
            valueAtTimeTxn = fiatFormatter.string(from: totalFiat)
            
            guard let fee = transaction?.feeValue else { return }
            
            if let feeCurrencySymbol = feeCurrencySymbol,
               feeCurrencySymbol != currencySymbol {
                tickers = try await currencyInfo.getHistory(
                    for: feeCurrencySymbol,
                    date: date
                ).get()
                
                guard
                    let feeTicker = tickers[.init(
                        crypto: feeCurrencySymbol,
                        fiat: currentFiat
                    )]
                else { return }
                
                ticker = feeTicker
            }
            
            let totalFeeFiat = fee * ticker
            feeAtTimeTxn = fiatFormatter.string(from: totalFeeFiat)
        }
    }
    
    func updateIncosinstentRowIfNeeded() {
        guard case .inconsistent = transactionStatus,
              let section = form.sectionBy(tag: Sections.inconsistentReason.tag)
        else { return }
        
        section.evaluateHidden()
        
        checkAddressesIfNeeded()
    }
    
    func updateTxDataRow() {
        let row = form.rowBy(tag: Rows.txBlockchainComment.tag)
        row?.evaluateHidden()
    }
    
    // MARK: - Other
    
    private func setColors() {
        view.backgroundColor = UIColor.adamant.secondBackgroundColor
        tableView.backgroundColor = .clear
    }
    
    func updateTransactionStatus() {
        guard let transaction = transaction,
              let richTransaction = richTransaction
        else { return }
                
        let failedTransaction = SimpleTransactionDetails(
            txId: transaction.txId,
            senderAddress: transaction.senderAddress,
            recipientAddress: transaction.recipientAddress,
            dateValue: transaction.dateValue,
            amountValue: transaction.amountValue,
            feeValue: transaction.feeValue,
            confirmationsValue: transaction.confirmationsValue,
            blockValue: transaction.blockValue,
            isOutgoing: transaction.isOutgoing,
            transactionStatus: richTransaction.transactionStatus,
            nonceRaw: transaction.nonceRaw
        )
        
        self.transaction = failedTransaction
        tableView.reloadData()
        updateIncosinstentRowIfNeeded()
    }

    @MainActor
    private func updateValueAtTimeRowValue() {
        guard let row: LabelRow = form.rowBy(tag: Rows.historyFiat.tag)
        else { return }
        
        row.value = valueAtTimeTxn
        row.updateCell()
    }
    
    @MainActor
    private func updateFeeAtTimeRowValue() {
        guard let row: LabelRow = form.rowBy(tag: Rows.fee.tag)
        else { return }
        
        row.value = getFeeValue()
        row.updateCell()
    }
    
    func getFeeValue() -> String {
        guard let value = transaction?.feeValue else {
            return TransactionDetailsViewControllerBase.awaitingValueString
        }
        
        let feeValueRaw = feeFormatter.string(from: value) ?? ""
        
        if let feeAtTimeTxn = feeAtTimeTxn {
            return "\(feeValueRaw) ~\(feeAtTimeTxn)"
        }
        
        return feeValueRaw
    }
    
    @MainActor
    func checkAddressesIfNeeded() {
        Task {
            guard let senderAddress = senderId,
                  let recipientAddress = recipientId,
                  transactionStatus?.isInconsistent == true
            else {
                return
            }
            
            let realSenderAddress = try? await walletService?.core.getWalletAddress(
                byAdamantAddress: senderAddress
            )
            
            let realRecipientAddress = try? await walletService?.core.getWalletAddress(
                byAdamantAddress: recipientAddress
            )
            
            if realSenderAddress != transaction?.senderAddress {
                senderName = nil
            } else {
                senderName = getName(by: senderId)
            }
            
            if realRecipientAddress != transaction?.recipientAddress {
                recipientName = nil
            } else {
                recipientName = getName(by: recipientId)
            }
            
            tableView.reloadData()
        }
    }
    
    func getName(by adamantAddress: String?) -> String? {
        guard let id = adamantAddress,
              let address = accountService.account?.address
        else { return  nil }
        
        if id.caseInsensitiveCompare(address) == .orderedSame {
            return String.adamant.transactionDetails.yourAddress
        }
        
        return addressBookService.getName(for: id)
    }
    
    // MARK: - Actions
    
    @objc func share(_ sender: UIBarButtonItem) {
        guard let transaction = transaction else {
            return
        }
        
        let alert = UIAlertController(
            title: nil,
            message: nil,
            preferredStyleSafe: .actionSheet,
            source: .barButtonItem(sender)
        )
        
        alert.addAction(UIAlertAction(title: String.adamant.alert.cancel, style: .cancel, handler: nil))
        
        if let url = explorerUrl(for: transaction) {
            // URL
            alert.addAction(UIAlertAction(title: String.adamant.alert.exportUrlButton, style: .default) { [weak self] _ in
                let alert = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                alert.modalPresentationStyle = .overFullScreen
                self?.present(alert, animated: true, completion: nil)
            })
        }

        // Description
        if let summary = summary(for: transaction) {
            alert.addAction(UIAlertAction(title: String.adamant.alert.exportSummaryButton, style: .default) { [weak self] _ in
                let text = summary
                let alert = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                alert.modalPresentationStyle = .overFullScreen
                self?.present(alert, animated: true, completion: nil)
            })
        }
        
        present(alert, animated: true, completion: nil)
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
    
    // MARK: - To override
    
    var currencySymbol: String?
    
    // MARK: - Fix this later
    var senderName: String?
    var recipientName: String?
    var comment: String?
    
    func explorerUrl(for transaction: TransactionDetails) -> URL? {
        return nil
    }
    
    func summary(for transaction: TransactionDetails) -> String? {
        guard let amount = transaction.amountValue,
              let symbol = currencySymbol,
              let rate = currencyInfo.getRate(for: symbol),
              !transaction.recipientAddress.isEmpty
        else {
            return nil
        }
        
        let value = amount * rate
        let currentValue = fiatFormatter.string(from: value)
        
        return transaction.summary(
            with: explorerUrl(for: transaction)?.absoluteString,
            currentValue: currentValue,
            valueAtTimeTxn: valueAtTimeTxn
        )
    }
}
