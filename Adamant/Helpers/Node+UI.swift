//
//  Node+UI.swift
//  Adamant
//
//  Created by Andrew G on 20.11.2023.
//  Copyright © 2023 Adamant. All rights reserved.
//

import CommonKit
import UIKit

extension Node {
    enum HeightType {
        case date
        case blocks
    }
    
    // swiftlint:disable switch_case_alignment
    func statusString(showVersion: Bool, heightType: HeightType?) -> String? {
        guard isEnabled else { return Strings.disabled }
        
        let statusTitle = switch connectionStatus {
        case .allowed:
            pingString
        case let .synchronizing(isFinal):
            isFinal
                ? Strings.synchronizing
                : Strings.updating
        case .offline:
            Strings.offline
        case .notAllowed(let reason):
            reason.text
        case .none:
            Strings.updating
        }
        
        let heightString: String?
        switch heightType {
        case .date:
            heightString = dateHeightString
        case .blocks:
            heightString = blocksHeightString
        case nil:
            heightString = nil
        }
        
        return [
            statusTitle,
            showVersion ? versionString : nil,
            heightString
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
    
    func indicatorString(isRest: Bool, isWs: Bool) -> String {
        let connections = [
            isRest ? preferredOrigin.scheme.rawValue : nil,
            isWs ? "ws" : nil
        ].compactMap { $0 }
        
        return [
            "●",
            connections.isEmpty
                ? nil
                : connections.joined(separator: ", ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
    
    var indicatorColor: UIColor {
        guard isEnabled else { return .adamant.inactive }
        
        switch connectionStatus {
        case .allowed:
            return .adamant.success
        case let .synchronizing(isFinal):
            return isFinal
                ? .adamant.attention
                : .adamant.inactive
        case .offline, .notAllowed:
            return .adamant.warning
        case .none:
            return .adamant.inactive
        }
    }
    
    var title: String {
        mainOrigin.asString()
    }
    
    var statusStringColor: UIColor {
        guard isEnabled else { return .adamant.textColor }
        
        return switch connectionStatus {
        case .none:
            .adamant.inactive
        case .allowed, .notAllowed, .offline, .synchronizing:
            .adamant.textColor
        }
    }
    
    var titleColor: UIColor {
        guard isEnabled else { return .adamant.textColor }
        
        return switch connectionStatus {
        case .none:
            .adamant.inactive
        case .allowed, .notAllowed, .offline, .synchronizing:
            .adamant.textColor
        }
    }
}

private extension Node {
    enum Strings {
        static var ping: String {
            String.localized(
                "NodesList.NodeCell.Ping",
                comment: "NodesList.NodeCell: Node ping"
            )
        }
        
        static var milliseconds: String {
            String.localized(
                "NodesList.NodeCell.Milliseconds",
                comment: "NodesList.NodeCell: Milliseconds"
            )
        }
        
        static var synchronizing: String {
            String.localized(
                "NodesList.NodeCell.Synchronizing",
                comment: "NodesList.NodeCell: Node is synchronizing"
            )
        }
        
        static var updating: String {
            String.localized(
                "NodesList.NodeCell.Updating",
                comment: "NodesList.NodeCell: Node is updating"
            )
        }
        
        static var offline: String {
            String.localized(
                "NodesList.NodeCell.Offline",
                comment: "NodesList.NodeCell: Node is offline"
            )
        }
        
        static var version: String {
            String.localized(
                "NodesList.NodeCell.Version",
                comment: "NodesList.NodeCell: Node version"
            )
        }
        
        static var disabled: String {
            String.localized(
                "NodesList.NodeCell.Disabled",
                comment: "NodesList.NodeCell: Node is disabled"
            )
        }
    }
    
    var pingString: String? {
        guard let ping = ping else { return nil }
        return "\(Strings.ping): \(Int(ping * 1000)) \(Strings.milliseconds)"
    }
    
    var blocksHeightString: String? {
        height.map { " ❐ \(getFormattedHeight(from: $0))" }
    }
    
    var dateHeightString: String? {
        height.map { " ❐ \(Date(timeIntervalSince1970: .init($0)).humanizedTime().string)" }
    }
    
    var versionString: String? {
        version.map { "(v\($0.string))" }
    }
    
    var numberFormatter: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        return numberFormatter
    }
    
    func getFormattedHeight(from height: Int) -> String {
        numberFormatter.string(from: Decimal(height)) ?? String(height)
    }
}
