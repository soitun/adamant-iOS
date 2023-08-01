//
//  ChatTransactionContainerView.swift
//  Adamant
//
//  Created by Andrey Golubenko on 11.01.2023.
//  Copyright © 2023 Adamant. All rights reserved.
//

import UIKit
import SnapKit
import Combine
import CommonKit

final class ChatTransactionContainerView: UIView, ChatModelView {
    var subscription: AnyCancellable?
    
    var model: Model = .default {
        didSet { update() }
    }
    
    var actionHandler: (ChatAction) -> Void = { _ in } {
        didSet { contentView.actionHandler = actionHandler }
    }
    
    private let contentView = ChatTransactionContentView()
    
    private lazy var statusButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(onStatusButtonTap), for: .touchUpInside)
        return button
    }()
    
    private let spacingView: UIView = {
        let view = UIView()
        view.setContentCompressionResistancePriority(.dragThatCanResizeScene, for: .horizontal)
        return view
    }()
    
    private let horizontalStack: UIStackView = {
        let stack = UIStackView()
        stack.alignment = .center
        stack.axis = .horizontal
        stack.spacing = 12
        return stack
    }()
    
    private lazy var swipeView: SwipeableView = {
        let view = SwipeableView(frame: .zero, view: self)
        return view
    }()
    
    private lazy var chatMenuManager: ChatMenuManager = {
        let manager = ChatMenuManager(
            menu: makeContextMenu(),
            backgroundColor: nil
        )
        return manager
    }()
    
    var isSelected: Bool = false {
        didSet {
            contentView.isSelected = isSelected
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
}

extension ChatTransactionContainerView: ReusableView {
    func prepareForReuse() {
        model = .default
        actionHandler = { _ in }
    }
}

private extension ChatTransactionContainerView {
    func configure() {
        addSubview(swipeView)
        swipeView.snp.makeConstraints { make in
            make.directionalEdges.equalToSuperview()
        }
        
        addSubview(horizontalStack)
        horizontalStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        
        swipeView.didSwipeAction = { [weak self] in
            guard let self = self else { return }
            self.actionHandler(.reply(message: self.model))
        }
        
        swipeView.swipeStateAction = { [weak self] state in
            self?.actionHandler(.swipeState(state: state))
        }
        
        let interaction = UIContextMenuInteraction(delegate: chatMenuManager)
        contentView.addInteraction(interaction)
    }
    
    func update() {
        contentView.model = model.content
        updateStatus(model.status)
        updateLayout()
    }
    
    func updateStatus(_ status: TransactionStatus) {
        statusButton.setImage(status.image, for: .normal)
        statusButton.tintColor = status.imageTintColor
    }
    
    func updateLayout() {
        var viewsList = [spacingView, statusButton, contentView]
        
        viewsList = model.isFromCurrentSender
            ? viewsList
            : viewsList.reversed()
        
        guard horizontalStack.arrangedSubviews != viewsList else { return }
        horizontalStack.arrangedSubviews.forEach(horizontalStack.removeArrangedSubview)
        viewsList.forEach(horizontalStack.addArrangedSubview)
    }
    
    @objc func onStatusButtonTap() {
        actionHandler(.forceUpdateTransactionStatus(id: model.id))
    }
}

extension ChatTransactionContainerView.Model {
    func height(for width: CGFloat) -> CGFloat {
        content.height(for: width)
    }
}

private extension TransactionStatus {
    var image: UIImage {
        switch self {
        case .notInitiated: return .asset(named: "status_updating") ?? .init()
        case .pending, .registered, .noNetwork, .noNetworkFinal: return .asset(named: "status_pending") ?? .init()
        case .success: return .asset(named: "status_success") ?? .init()
        case .failed: return .asset(named: "status_failed") ?? .init()
        case .inconsistent: return .asset(named: "status_warning") ?? .init()
        }
    }
    
    var imageTintColor: UIColor {
        switch self {
        case .notInitiated: return .adamant.secondary
        case .pending, .registered, .noNetwork, .noNetworkFinal: return .adamant.primary
        case .success: return .adamant.active
        case .failed, .inconsistent: return .adamant.alert
        }
    }
}

extension ChatTransactionContainerView {
    func makeContextMenu() -> UIMenu {
        let remove = UIAction(
            title: .adamant.chat.remove,
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { _ in
            self.actionHandler(.remove(id: self.model.id))
        }
        
        let report = UIAction(
            title: .adamant.chat.report,
            image: UIImage(systemName: "exclamationmark.bubble")
        ) { _ in
            self.actionHandler(.report(id: self.model.id))
        }
        
        let reply = UIAction(
            title: .adamant.chat.reply,
            image: UIImage(systemName: "arrowshape.turn.up.left")
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { self.actionHandler(.reply(message: self.model)) }
        }
        
        return UIMenu(title: "", children: [reply, report, remove])
    }
}
