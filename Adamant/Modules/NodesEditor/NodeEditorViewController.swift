//
//  NodeEditorViewController.swift
//  Adamant
//
//  Created by Anokhov Pavel on 20.06.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka
import CommonKit

// MARK: - Localization
extension String.adamant {
    enum nodesEditor {
        static var newNodeTitle: String {
            String.localized("NodesEditor.NewNodeTitle", comment: "NodesEditor: New node scene title")
        }
        static var deleteNodeAlert: String {
            String.localized("NodesEditor.DeleteNodeAlert", comment: "NodesEditor: Delete node confirmation message")
        }
        static var failedToBuildURL: String {
            String.localized("NodesEditor.FailedToBuildURL", comment: "NodesEditor: Failed to build URL alert")
        }
    }
}

// MARK: - Helpers
enum NodeEditorResult {
    case new(node: Node)
    case nodeUpdated
    case cancel
    case delete(node: Node)
}

@MainActor
protocol NodeEditorDelegate: AnyObject {
    func nodeEditorViewController(_ editor: NodeEditorViewController, didFinishEditingWithResult result: NodeEditorResult)
}

// MARK: - NodeEditorViewController
final class NodeEditorViewController: FormViewController {
    // MARK: - Rows
    
    private enum Rows {
        // Node properties
        case host, port, scheme
        
        // Buttons
        case deleteButton
        
        // Rows
        case webSockets
        
        var localized: String {
            switch self {
            case .scheme: return .localized("NodesEditor.SchemeRow", comment: "NodesEditor: Scheme row")
            case .port: return .localized("NodesEditor.PortRow", comment: "NodesEditor: Port row")
            case .host: return .localized("NodesEditor.HostRow", comment: "NodesEditor: Host row")
            case .webSockets: return .localized("NodesEditor.WebSockets", comment: "NodesEditor: Web sockets")
            case .deleteButton: return .localized("NodesEditor.DeleteNodeButton", comment: "NodesEditor: Delete node button")
            }
        }
        
        var placeholder: String? {
            switch self {
            case .host: return .localized("NodesEditor.HostRow.Placeholder", comment: "NodesEditor: Host row placeholder")
            case .port, .scheme, .webSockets, .deleteButton: return nil
            }
        }
        
        var tag: String {
            switch self {
            case .scheme: return "prtcl"
            case .port: return "prt"
            case .host: return "url"
            case .webSockets: return "webSockets"
            case .deleteButton: return "delete"
            }
        }
    }
    
    private enum WebSocketsState {
        case supported
        case notSupported
        
        var localized: String {
            switch self {
            case .supported: return .localized("NodesEditor.WebSocketsSupported", comment: "NodesEditor: Web sockets are supported")
            case .notSupported: return .localized("NodesEditor.WebSocketsNotSupported", comment: "NodesEditor: Web sockets aren't supported")
            }
        }
    }
    
    // MARK: - Dependencies
    var dialogService: DialogService!
    var apiService: AdamantApiServiceProtocol!
    var nodesStorage: NodesStorageProtocol!
    
    // MARK: - Properties
    var node: Node?
    
    weak var delegate: NodeEditorDelegate?
    private var didCallDelegate: Bool = false
    
    override var customNavigationAccessoryView: (UIView & NavigationAccessory)? {
        let accessory = NavigationAccessoryView()
        accessory.tintColor = UIColor.adamant.primary
        return accessory
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let node = node {
            self.navigationItem.title = node.mainOrigin.host
        } else {
            self.navigationItem.title = String.adamant.nodesEditor.newNodeTitle
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveNode))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        
        // MARK: - Node properties
        form +++ Section()
            
        // URL
        <<< TextRow {
            $0.title = Rows.host.localized
            $0.tag = Rows.host.tag
            $0.placeholder = Rows.host.placeholder
            
            $0.value = node?.mainOrigin.host
        }
            
        // Port
        <<< IntRow {
            $0.title = Rows.port.localized
            $0.tag = Rows.port.tag
            
            if let node = node {
                $0.value = node.mainOrigin.port
                $0.placeholder = String(node.mainOrigin.scheme.defaultPort)
            } else {
                $0.placeholder = String(NodeOrigin.URLScheme.default.defaultPort)
            }
        }
        
        // Scheme
        <<< PickerInlineRow<NodeOrigin.URLScheme> {
            $0.title = Rows.scheme.localized
            $0.tag = Rows.scheme.tag
            $0.value = node?.mainOrigin.scheme ?? NodeOrigin.URLScheme.default
            $0.options = [.https, .http]
            $0.baseCell.detailTextLabel?.textColor = .adamant.textColor
        }.onExpandInlineRow { (cell, _, inlineRow) in
            inlineRow.cell.height = { 100 }
        }.onChange { [weak self] row in
            if let portRow: IntRow = self?.form.rowBy(tag: Rows.port.tag) {
                if let scheme = row.value {
                    portRow.placeholder = String(scheme.defaultPort)
                } else {
                    portRow.placeholder = String(NodeOrigin.URLScheme.default.defaultPort)
                }
                
                portRow.updateCell()
            }
        }
        
        // MARK: - WebSockets
        
        if let wsEnabled = node?.wsEnabled {
            form +++ Section()

            <<< LabelRow {
                $0.title = Rows.webSockets.localized
                $0.tag = Rows.webSockets.tag
                $0.baseValue = wsEnabled
                    ? WebSocketsState.supported.localized
                    : WebSocketsState.notSupported.localized
            }
        }
        
        // MARK: - Delete
            
        if node != nil {
            form +++ Section()
            <<< ButtonRow {
                $0.title = Rows.deleteButton.localized
                $0.tag = Rows.deleteButton.tag
            }.onCellSelection { [weak self] (_, _) in
                self?.deleteNode()
            }
        }
        
        setColors()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if !didCallDelegate {
            saveNode()
        }
    }
    
    // MARK: - Other
    
    private func setColors() {
        view.backgroundColor = UIColor.adamant.secondBackgroundColor
        tableView.backgroundColor = .clear
    }
}

// MARK: - Actions
extension NodeEditorViewController {
    @objc private func saveNode() {
        guard let row: TextRow = form.rowBy(tag: Rows.host.tag), let rawUrl = row.value else {
            didCallDelegate = true
            delegate?.nodeEditorViewController(self, didFinishEditingWithResult: .cancel)
            return
        }
        
        let host = rawUrl.trimmingCharacters(in: .whitespaces)
        let scheme: NodeOrigin.URLScheme
        
        if
            let row = form.rowBy(tag: Rows.scheme.tag),
            let value = row.baseValue as? NodeOrigin.URLScheme
        {
            scheme = value
        } else {
            scheme = .default
        }
        
        let port: Int?
        if let row: IntRow = form.rowBy(tag: Rows.port.tag), let p = row.value {
            port = p
        } else {
            port = nil
        }
        
        let result: NodeEditorResult
        if let node = node {
            nodesStorage.updateNode(id: node.id, group: .adm) { node in
                node.mainOrigin.scheme = scheme
                node.mainOrigin.host = host
                node.mainOrigin.port = port
            }
            
            result = .nodeUpdated
        } else {
            result = .new(node: .init(
                id: .init(),
                isEnabled: true,
                wsEnabled: false,
                mainOrigin: .init(
                    scheme: scheme,
                    host: host,
                    port: port
                ),
                altOrigin: nil,
                version: nil,
                height: nil,
                ping: nil,
                connectionStatus: nil,
                preferMainOrigin: nil,
                type: .custom
            ))
        }
        
        didCallDelegate = true
        delegate?.nodeEditorViewController(self, didFinishEditingWithResult: result)
    }
    
    @objc private func cancel() {
        didCallDelegate = true
        delegate?.nodeEditorViewController(self, didFinishEditingWithResult: .cancel)
    }
    
    private func deleteNode() {
        let alert = UIAlertController(title: String.adamant.nodesEditor.deleteNodeAlert, message: nil, preferredStyleSafe: .alert, source: nil)
        alert.addAction(UIAlertAction(title: String.adamant.alert.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: String.adamant.alert.delete, style: .destructive, handler: { _ in
            self.didCallDelegate = true
            
            if let node = self.node {
                self.delegate?.nodeEditorViewController(self, didFinishEditingWithResult: .delete(node: node))
            } else {
                self.delegate?.nodeEditorViewController(self, didFinishEditingWithResult: .cancel)
            }
        }))
        alert.modalPresentationStyle = .overFullScreen
        present(alert, animated: true, completion: nil)
    }
}
