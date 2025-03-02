//
//  NodeConnectionStatus.swift
//
//
//  Created by Andrew G on 28.07.2024.
//

import Foundation

public enum NodeConnectionStatus: Equatable, Codable, Sendable {
    case offline
    case synchronizing(isFinal: Bool)
    case allowed
    case notAllowed(RejectedReason)
}

public extension NodeConnectionStatus {
    enum RejectedReason: Codable, Equatable, Sendable {
        case outdatedApiVersion
    }
}

public extension NodeConnectionStatus.RejectedReason {
    var text: String {
        switch self {
        case .outdatedApiVersion:
            return String.localized(
                "NodesList.NodeCell.Outdated",
                comment: "NodesList.NodeCell: Node is outdated"
            )
        }
    }
}
