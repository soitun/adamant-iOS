//
//  ChatMediaContainerView.swift
//  Adamant
//
//  Created by Stanislav Jelezoglo on 14.02.2024.
//  Copyright © 2024 Adamant. All rights reserved.
//

import UIKit
import Combine
import CommonKit

final class ChatMediaContainerView: UIView {
    private let spacingView: UIView = {
        let view = UIView()
        view.setContentCompressionResistancePriority(.dragThatCanResizeScene, for: .horizontal)
        return view
    }()
    
    private lazy var horizontalStack: UIStackView = {
        let stack = UIStackView()
        stack.alignment = .center
        stack.axis = .horizontal
        stack.spacing = horizontalStackSpace
        return stack
    }()
    
    private lazy var ownReactionLabel: UILabel = {
        let label = UILabel()
        label.text = getReaction(for: model.address)
        label.backgroundColor = .adamant.pickedReactionBackground
        label.layer.cornerRadius = ownReactionSize.height / 2
        label.textAlignment = .center
        label.layer.masksToBounds = true
        
        label.snp.makeConstraints { make in
            make.width.equalTo(ownReactionSize.width)
            make.height.equalTo(ownReactionSize.height)
        }
        
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(tapReactionAction)
        )
        
        label.addGestureRecognizer(tapGesture)
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private lazy var opponentReactionLabel: UILabel = {
        let label = UILabel()
        label.text = getReaction(for: model.opponentAddress)
        label.textAlignment = .center
        label.layer.masksToBounds = true
        label.backgroundColor = .adamant.pickedReactionBackground
        label.layer.cornerRadius = opponentReactionSize.height / 2
        
        label.snp.makeConstraints { make in
            make.width.equalTo(opponentReactionSize.width)
            make.height.equalTo(opponentReactionSize.height)
        }
        
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(tapReactionAction)
        )
        
        label.addGestureRecognizer(tapGesture)
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private lazy var reactionsStack: UIStackView = {
        let stack = UIStackView()
        stack.alignment = .center
        stack.axis = .vertical
        stack.spacing = reactionsStackSpace

        stack.addArrangedSubview(statusButton)
        stack.addArrangedSubview(ownReactionLabel)
        stack.addArrangedSubview(opponentReactionLabel)
        return stack
    }()
    
    private lazy var statusButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(onStatusButtonTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var contentView = ChatMediaContentView()
    private lazy var chatMenuManager = ChatMenuManager(delegate: self)

    // MARK: Dependencies
    
    var chatMessagesListViewModel: ChatMessagesListViewModel?
    
    var model: Model = .default {
        didSet { update() }
    }
    
    var actionHandler: (ChatAction) -> Void = { _ in } {
        didSet { contentView.actionHandler = actionHandler }
    }
    
    var isSelected: Bool = false {
        didSet {
            contentView.isSelected = isSelected
        }
    }
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    @objc func onStatusButtonTap() {
        if model.status == .failed,
           let file = model.content.fileModel.files.first {
            actionHandler(.openFile(messageId: model.id, file: file))
            return
        }
        
        guard case .needToDownload = model.status else {
            return
        }
        
        let fileModel = model.content.fileModel
        let fileList = Array(fileModel.files.prefix(FilesConstants.maxFilesCount))
        
        actionHandler(.forceDownloadAllFiles(
            messageId: fileModel.messageId,
            files: fileList
        ))
    }
}

extension ChatMediaContainerView {
    func configure() {
        addSubview(horizontalStack)
        horizontalStack.snp.makeConstraints {
            $0.verticalEdges.equalToSuperview()
            $0.horizontalEdges.equalToSuperview().inset(4)
        }
        
        reactionsStack.snp.makeConstraints { $0.width.equalTo(reactionsWidth) }
        chatMenuManager.setup(for: contentView)
    }
    
    func update() {
        contentView.model = model.content
        updateLayout()
        ownReactionLabel.isHidden = getReaction(for: model.address) == nil
        opponentReactionLabel.isHidden = getReaction(for: model.opponentAddress) == nil
        updateOwnReaction()
        updateOpponentReaction()
        updateStatus(model.status)
    }
    
    func updateStatus(_ status: FileMessageStatus) {
        statusButton.setImage(status.image, for: .normal)
        statusButton.tintColor = status.imageTintColor
        statusButton.isHidden = status == .success
    }
    
    func updateLayout() {
        var viewsList = [spacingView, reactionsStack, contentView]
        
        viewsList = model.isFromCurrentSender
            ? viewsList
            : viewsList.reversed()
        
        guard horizontalStack.arrangedSubviews != viewsList else { return }
        horizontalStack.arrangedSubviews.forEach { horizontalStack.removeArrangedSubview($0) }
        viewsList.forEach { horizontalStack.addArrangedSubview($0) }
    }
    
    func updateOwnReaction() {
        ownReactionLabel.text = getReaction(for: model.address)
        ownReactionLabel.backgroundColor = model.content.backgroundColor.uiColor.mixin(
            infusion: .lightGray,
            alpha: 0.15
        )
    }
    
    func updateOpponentReaction() {
        guard let reaction = getReaction(for: model.opponentAddress),
              let senderPublicKey = getSenderPublicKeyInReaction(for: model.opponentAddress)
        else {
            opponentReactionLabel.attributedText = nil
            opponentReactionLabel.text = nil
            return
        }
        
        let fullString = NSMutableAttributedString(string: reaction)
        
        if let image = chatMessagesListViewModel?.avatarService.avatar(
            for: senderPublicKey,
            size: opponentReactionImageSize.width
        ) {
            let replyImageAttachment = NSTextAttachment()
            replyImageAttachment.image = image
            replyImageAttachment.bounds = .init(
                origin: .init(x: .zero, y: -3),
                size: opponentReactionImageSize
            )
            
            let imageString = NSAttributedString(attachment: replyImageAttachment)
            fullString.append(NSAttributedString(string: " "))
            fullString.append(imageString)
        }
        
        opponentReactionLabel.attributedText = fullString
        opponentReactionLabel.backgroundColor = model.content.backgroundColor.uiColor.mixin(
            infusion: .lightGray,
            alpha: 0.15
        )
    }
    
    func getSenderPublicKeyInReaction(for senderAddress: String) -> String? {
        model.reactions?.first(
            where: { $0.sender == senderAddress }
        )?.senderPublicKey
    }
    
    func getReaction(for address: String) -> String? {
        model.reactions?.first(
            where: { $0.sender == address }
        )?.reaction
    }
    
    @objc func tapReactionAction() {
        chatMenuManager.presentMenuProgrammatically(for: contentView)
    }
}

extension ChatMediaContainerView: ChatMenuManagerDelegate {
    func getCopyView() -> UIView? {
        copy(with: model)?.contentView
    }
    
    func presentMenu(
        copyView: UIView,
        size: CGSize,
        location: CGPoint,
        tapLocation: CGPoint,
        getPositionOnScreen: @escaping () -> CGPoint
    ) {
        let arguments = ChatContextMenuArguments.init(
            copyView: copyView,
            size: size,
            location: location,
            tapLocation: tapLocation,
            messageId: model.id,
            menu: makeContextMenu(),
            selectedEmoji: getReaction(for: model.address),
            getPositionOnScreen: getPositionOnScreen
        )
        actionHandler(.presentMenu(arg: arguments))
    }
}

extension ChatMediaContainerView {
    func makeContextMenu() -> AMenuSection {
        let remove = AMenuItem.action(
            title: .adamant.chat.remove,
            systemImageName: "trash",
            style: .destructive
        ) { [actionHandler, model] in
            actionHandler(.remove(id: model.id))
        }
        
        let report = AMenuItem.action(
            title: .adamant.chat.report,
            systemImageName: "exclamationmark.bubble"
        ) { [actionHandler, model] in
            actionHandler(.report(id: model.id))
        }
        
        let reply = AMenuItem.action(
            title: .adamant.chat.reply,
            systemImageName: "arrowshape.turn.up.left"
        ) { [actionHandler, model] in
            actionHandler(.reply(id: model.id))
        }
        
        let copy = AMenuItem.action(
            title: .adamant.chat.copy,
            systemImageName: "doc.on.doc"
        ) { [actionHandler, model] in
            actionHandler(.copy(text: model.content.comment.string))
        }
        
        let actions: [AMenuItem] = model.content.comment.string.isEmpty
        ? [reply, report, remove]
        : [reply, copy, report, remove]
        
        return AMenuSection(actions)
    }
}

extension ChatMediaContainerView {
    func copy(with model: Model) -> ChatMediaContainerView? {
        let view = ChatMediaContainerView(frame: frame)
        view.contentView.model = model.content
        return view
    }
}

extension ChatMediaContainerView.Model {
    @MainActor
    func height() -> CGFloat {
        content.height()
    }
}

private let contentWidth: CGFloat = 260
private let reactionsWidth: CGFloat = 50
private let horizontalStackSpace: CGFloat = 5
private let reactionsStackSpace: CGFloat = 12
private let ownReactionSize = CGSize(width: 40, height: 27)
private let opponentReactionSize = CGSize(width: 55, height: 27)
private let opponentReactionImageSize = CGSize(width: 12, height: 12)
