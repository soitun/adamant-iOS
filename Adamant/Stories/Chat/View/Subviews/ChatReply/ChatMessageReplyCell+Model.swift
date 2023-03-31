//
//  ChatMessageReplyCell+Model.swift
//  Adamant
//
//  Created by Stanislav Jelezoglo on 30.03.2023.
//  Copyright © 2023 Adamant. All rights reserved.
//

import UIKit

extension ChatMessageReplyCell {
    struct Model: Equatable, MessageModel {
        let id: String
        let replyId: String
        let message: NSAttributedString
        let messageReply: NSAttributedString
        let backgroundColor: ChatMessageBackgroundColor
        
        static let `default` = Self(
            id: "",
            replyId: "",
            message: NSAttributedString(string: ""),
            messageReply: NSAttributedString(string: ""),
            backgroundColor: .failed
        )
        
        func makeReplyContent() -> NSAttributedString {
            return message
        }
    }
}

extension ChatMessageReplyCell.Model {
    func contentHeight(for width: CGFloat) -> CGFloat {
        let maxSize = CGSize(width: width, height: .infinity)
        
        let messageHeight = message.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height
        
        return verticalInsets * 2
        + verticalStackSpacing
        + messageHeight
        + messageReplyHeight
    }
}

private let verticalStackSpacing: CGFloat = 12
private let verticalInsets: CGFloat = 8
private let messageReplyHeight: CGFloat = 20
