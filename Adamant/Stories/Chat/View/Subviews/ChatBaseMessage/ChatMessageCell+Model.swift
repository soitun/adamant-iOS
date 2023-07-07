//
//  ChatMessageCell+Model.swift
//  Adamant
//
//  Created by Stanislav Jelezoglo on 30.03.2023.
//  Copyright © 2023 Adamant. All rights reserved.
//

import UIKit

extension ChatMessageCell {
    struct Model: ChatReusableViewModelProtocol, MessageModel {
        let id: String
        let text: NSAttributedString
        let backgroundColor: ChatMessageBackgroundColor
        let isFromCurrentSender: Bool
        
        static let `default` = Self(
            id: "",
            text: NSAttributedString(string: ""),
            backgroundColor: .failed,
            isFromCurrentSender: false
        )
        
        func makeReplyContent() -> NSAttributedString {
            return text
        }
    }
}
