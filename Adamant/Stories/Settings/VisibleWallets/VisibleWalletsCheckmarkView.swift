//
//  VisibleWalletsCheckmarkView.swift
//  Adamant
//
//  Created by Stanislav Jelezoglo on 21.12.2022.
//  Copyright © 2022 Adamant. All rights reserved.
//

import SnapKit
import UIKit

final class VisibleWalletsCheckmarkRowView: UIView {
    private let checkmarkView = CheckmarkView()
    private let titleLabel = makeTitleLabel()
    private let subtitleLabel = makeSubtitleLabel()
    private let captionLabel = makeCaptionLabel()
    private let logoImageView = makeImageView()
    private let balanceLabel = makeAdditionalLabel()
    
    private lazy var horizontalStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [captionLabel, subtitleLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()
    
    var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }
    
    var subtitle: String? {
        get { subtitleLabel.text }
        set { subtitleLabel.text = newValue }
    }
    
    var caption: String? {
        get { captionLabel.text }
        set { captionLabel.text = newValue }
    }
    
    var captionColor: UIColor {
        get { captionLabel.textColor }
        set { captionLabel.textColor = newValue }
    }
    
    var balance: Decimal? {
        didSet {
            balanceLabel.text = "\(balance ?? 0)"
            if balance == 0 {
                balanceLabel.font = captionLabel.font
            } else {
                balanceLabel.font = titleLabel.font
            }
        }
    }
    
    var onCheckmarkTap: (() -> Void)? {
        get { checkmarkView.onCheckmarkTap }
        set { checkmarkView.onCheckmarkTap = newValue }
    }
    
    var checkmarkImage: UIImage? {
        get { checkmarkView.image }
        set { checkmarkView.image = newValue }
    }
    
    var logoImage: UIImage? {
        get { logoImageView.image }
        set { logoImageView.image = newValue }
    }
    
    var isChecked: Bool {
        checkmarkView.isChecked
    }
    
    var isUpdating: Bool {
        checkmarkView.isUpdating
    }
    
    var checkmarkImageBorderColor: CGColor? {
        get { checkmarkView.imageBorderColor }
        set { checkmarkView.imageBorderColor = newValue }
    }
    
    var checkmarkImageTintColor: UIColor? {
        get { checkmarkView.imageTintColor }
        set { checkmarkView.imageTintColor = newValue }
    }
    
    init() {
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    func setIsChecked(_ isChecked: Bool, animated: Bool) {
        checkmarkView.setIsChecked(isChecked, animated: animated)
    }
    
    func setIsUpdating(_ isUpdating: Bool, animated: Bool) {
        checkmarkView.setIsUpdating(isUpdating, animated: animated)
    }
    
    private func setupView() {
        addSubview(logoImageView)
        logoImageView.snp.makeConstraints {
            $0.size.equalTo(25)
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(5)
        }
        
        addSubview(checkmarkView)
        checkmarkView.snp.makeConstraints {
            $0.size.equalTo(44)
            $0.top.trailing.bottom.equalToSuperview().inset(2)
        }
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(checkmarkView)
            $0.leading.equalTo(logoImageView.snp.trailing).offset(4)
        }
        
        addSubview(horizontalStack)
        horizontalStack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.leading.equalTo(titleLabel)
        }
        
        addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalTo(titleLabel.snp.trailing).offset(10)
        }
    }
}

private func makeTitleLabel() -> UILabel {
    let label = UILabel()
    label.font = .systemFont(ofSize: 17, weight: .regular)
    return label
}

private func makeSubtitleLabel() -> UILabel {
    let label = UILabel()
    label.font = .preferredFont(forTextStyle: .caption1)
    return label
}

private func makeCaptionLabel() -> UILabel {
    let label = UILabel()
    label.font = .systemFont(ofSize: 12, weight: .regular)
    return label
}

private func makeAdditionalLabel() -> UILabel {
    let label = UILabel()
    label.font = .systemFont(ofSize: 17, weight: .regular)
    return label
}

private func makeImageView() -> UIImageView {
    return UIImageView()
}
