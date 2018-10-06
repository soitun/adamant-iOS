//
//  RichMessageProvider.swift
//  Adamant
//
//  Created by Anokhov Pavel on 06.09.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import MessageKit

enum CellSource {
    case `class`(type: UICollectionViewCell.Type)
    case nib(nib: UINib)
}

protocol RichMessageProvider {
    static var richMessageType: String { get }
    
    var cellIdentifierSent: String { get }
    var cellIdentifierReceived: String { get }
    var cellSource: CellSource? { get }
	
    // MARK: Events
    func richMessageTapped(for transaction: RichMessageTransaction, at indexPath: IndexPath, in chat: ChatViewController)
    
    // MARK: Chats list
    func shortDescription(for transaction: RichMessageTransaction) -> String
    
    // MARK: MessageKit
    func cellSizeCalculator(for messagesCollectionViewFlowLayout: MessagesCollectionViewFlowLayout) -> CellSizeCalculator
    func cell(for message: MessageType, isFromCurrentSender: Bool, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UICollectionViewCell
}

protocol RichMessageProviderWithStatusCheck: RichMessageProvider {
    func statusForTransactionBy(hash: String, completion: @escaping (WalletServiceResult<TransactionStatus>) -> Void)
}
