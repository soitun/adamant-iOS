//
//  NodesListViewController.swift
//  Adamant
//
//  Created by Anton Boyarkin on 13/06/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka
import CommonKit
import Combine

// MARK: - Localization
extension String.adamant {
    struct nodesList {
        static let title = String.localized("NodesList.Title", comment: "NodesList: scene title")
        static let nodesListButton = String.localized("NodesList.NodesList", comment: "NodesList: Button label")
        
        static let defaultNodesWasLoaded = String.localized("NodeList.DefaultNodesLoaded", comment: "NodeList: Inform that default nodes was loaded, if user deleted all nodes")
        
        static let resetAlertTitle = String.localized("NodesList.ResetNodeListAlert", comment: "NodesList: Reset nodes alert title")
        
        private init() {}
    }
}

// MARK: - NodesListViewController
final class NodesListViewController: FormViewController {
    // Rows & Sections
    
    private enum Sections {
        case nodes
        case buttons
        case preferTheFastestNode
        
        var tag: String {
            switch self {
            case .nodes: return "nds"
            case .buttons: return "bttns"
            case .preferTheFastestNode: return "preferTheFastestNode"
            }
        }
    }
    
    private enum Rows {
        case addNode
        case save
        case reset
        case preferTheFastestNode
        
        var localized: String {
            switch self {
            case .addNode:
                return .localized("NodesList.AddNewNode", comment: "NodesList: 'Add new node' button lable")
                
            case .save:
                return String.adamant.alert.save
                
            case .reset:
                return .localized("NodesList.ResetButton", comment: "NodesList: 'Reset' button")
                
            case .preferTheFastestNode:
                return .localized("NodesList.PreferTheFastestNode", comment: "NodesList: 'Prefer the fastest node' switch")
            }
        }
    }
    
    // MARK: Dependencies
    
    private let dialogService: DialogService
    private let securedStore: SecuredStore
    private let screensFactory: ScreensFactory
    private let nodesStorage: NodesStorageProtocol
    private let nodesAdditionalParamsStorage: NodesAdditionalParamsStorageProtocol
    private let apiService: ApiService
    private let socketService: SocketService
    
    // Properties
    
    @ObservableValue private var nodesList = [Node]()
    @ObservableValue private var currentSocketsNodeId: UUID?
    @ObservableValue private var currentRestNodesIds = [UUID]()
    
    private var nodesHaveBeenDisplayed = false
    private var timerSubsctiption: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    
    init(
        dialogService: DialogService,
        securedStore: SecuredStore,
        screensFactory: ScreensFactory,
        nodesStorage: NodesStorageProtocol,
        nodesAdditionalParamsStorage: NodesAdditionalParamsStorageProtocol,
        apiService: ApiService,
        socketService: SocketService
    ) {
        self.dialogService = dialogService
        self.securedStore = securedStore
        self.screensFactory = screensFactory
        self.nodesStorage = nodesStorage
        self.nodesAdditionalParamsStorage = nodesAdditionalParamsStorage
        self.apiService = apiService
        self.socketService = socketService
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Isn't implemented")
    }
    
    private func setup() {
        nodesStorage.getNodesPublisher(group: nodeGroup)
            .combineLatest(nodesAdditionalParamsStorage.fastestNodeMode(group: nodeGroup))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.setNewNodesList($0.0) }
            .store(in: &subscriptions)
        
        NotificationCenter.default
            .publisher(for: .SocketService.currentNodeUpdate, object: nil)
            .receive(on: DispatchQueue.main)
            .map { [weak self] _ in self?.socketService.currentNode?.id }
            .removeDuplicates()
            .assign(to: _currentSocketsNodeId)
            .store(in: &subscriptions)
        
        currentSocketsNodeId = socketService.currentNode?.id
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = String.adamant.nodesList.title
        navigationOptions = .Disabled
        navigationItem.largeTitleDisplayMode = .always
        
        if splitViewController == nil, navigationController?.viewControllers.count == 1 {
            let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(NodesListViewController.close))
            navigationItem.rightBarButtonItem = done
        }
        
        // MARK: Nodes
        
        form +++ Section {
            $0.tag = Sections.nodes.tag
        }
        
        // MARK: Prefer the fastest node
        
        +++ Section {
            $0.tag = Sections.preferTheFastestNode.tag
        }
        
        <<< SwitchRow { [nodesAdditionalParamsStorage] in
            $0.title = Rows.preferTheFastestNode.localized
            $0.value = nodesAdditionalParamsStorage.isFastestNodeMode(
                group: nodeGroup
            )
        }.onChange { [nodesAdditionalParamsStorage] in
            nodesAdditionalParamsStorage.setFastestNodeMode(
                group: nodeGroup,
                value: $0.value ?? true
            )
        }.cellUpdate { cell, _ in
            cell.switchControl.onTintColor = .adamant.active
        }
        
        // MARK: Buttons
        
        +++ Section {
            $0.tag = Sections.buttons.tag
        }
        
        // Add node
        <<< ButtonRow {
            $0.title = Rows.addNode.localized
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
        }.onCellSelection { [weak self] (_, _) in
            self?.createNewNode()
        }
            
        // Reset
        <<< ButtonRow {
            $0.title = Rows.reset.localized
        }.onCellSelection { [weak self] (_, _) in
            self?.resetToDefault()
        }
        
        setColors()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        apiService.healthCheck()
        setHealthCheckTimer()
    }
    
    // MARK: - Other
    
    private func setColors() {
        view.backgroundColor = UIColor.adamant.secondBackgroundColor
        tableView.backgroundColor = .clear
    }
    
    private func setNewNodesList(_ newNodes: [Node]) {
        nodesList = newNodes
        currentRestNodesIds = apiService.preferredNodeIds
        
        if !nodesHaveBeenDisplayed {
            UIView.performWithoutAnimation {
                remakeNodesRows()
            }
        } else {
            remakeNodesRows()
        }
        
        nodesHaveBeenDisplayed = true
    }
}

// MARK: - Manipulating node list
extension NodesListViewController {
    func createNewNode() {
        presentEditor(forNode: nil)
    }
    
    func addNode(node: Node) {
        getNodesSection()?.append(createRowFor(nodeId: node.id, tag: generateRandomTag()))
        nodesStorage.addNode(node, group: nodeGroup)
    }
    
    func removeNode(nodeId: UUID) {
        guard let index = getNodeIndex(nodeId: nodeId) else { return }
        
        getNodesSection()?.remove(at: index)
        nodesStorage.removeNode(id: nodeId)
    }
    
    func getNodeIndex(nodeId: UUID) -> Int? {
        displayedNodesIds.firstIndex { $0 == nodeId }
    }
    
    func getNodesSection() -> Section? {
        form.sectionBy(tag: Sections.nodes.tag)
    }
    
    var displayedNodesIds: [UUID] {
        getNodesSection()?.allRows.compactMap {
            ($0.baseValue as? NodeCell.Model)?.id
        } ?? []
    }
    
    func editNode(_ node: Node) {
        presentEditor(forNode: node)
    }
    
    @objc func close() {
        if self.navigationController?.viewControllers.count == 1 {
            self.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func resetToDefault(silent: Bool = false) {
        if silent {
            nodesStorage.resetNodes(group: nodeGroup)
            return
        }
        
        let alert = UIAlertController(title: String.adamant.nodesList.resetAlertTitle, message: nil, preferredStyleSafe: .alert, source: nil)
        alert.addAction(UIAlertAction(title: String.adamant.alert.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(
            title: Rows.reset.localized,
            style: .destructive,
            handler: { [weak self] _ in self?.nodesStorage.resetNodes(group: nodeGroup) }
        ))
        alert.modalPresentationStyle = .overFullScreen
        present(alert, animated: true, completion: nil)
    }
    
    func remakeNodesRows() {
        guard
            let nodesSection = getNodesSection(),
            displayedNodesIds != nodesList.map({ $0.id })
        else { return }
        
        nodesSection.removeAll()
        
        for node in nodesList {
            let row = createRowFor(nodeId: node.id, tag: generateRandomTag())
            nodesSection.append(row)
        }
    }
}

// MARK: - NodeEditorDelegate
extension NodesListViewController: NodeEditorDelegate {
    func nodeEditorViewController(_ editor: NodeEditorViewController, didFinishEditingWithResult result: NodeEditorResult) {
        switch result {
        case .new(let node):
            addNode(node: node)
        case .delete(let editorNode):
            removeNode(nodeId: editorNode.id)
        case .nodeUpdated, .cancel:
            break
        }
        
        if UIScreen.main.traitCollection.userInterfaceIdiom == .pad {
            navigationController?.popToViewController(self, animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - Loading nodes

extension NodesListViewController {
    func loadDefaultNodes(showAlert: Bool) {
        nodesStorage.resetNodes(group: nodeGroup)
        
        if showAlert {
            dialogService.showSuccess(withMessage: String.adamant.nodesList.defaultNodesWasLoaded)
        }
    }
}

// MARK: - Tools
extension NodesListViewController {
    private func createRowFor(nodeId: UUID, tag: String) -> BaseRow {
        let row = NodeRow {
            $0.cell.subscribe(makeNodeCellPublisher(nodeId: nodeId))
            $0.tag = tag
            
            let deleteAction = SwipeAction(
                style: .destructive,
                title: "Delete"
            ) { [weak self] _, row, completionHandler in
                defer { completionHandler?(true) }
                
                guard let model = row.baseValue as? NodeCell.Model else { return }
                self?.removeNode(nodeId: model.id)
            }
            
            $0.trailingSwipe.actions = [deleteAction]
            $0.trailingSwipe.performsFirstActionWithFullSwipe = true
        }.cellUpdate { (cell, _) in
            if let label = cell.textLabel {
                label.textColor = UIColor.adamant.primary
            }
        }.onCellSelection { [weak self] (_, row) in
            defer { row.deselect(animated: true) }
            
            guard
                let self = self,
                let node = self.nodesList.first(where: { $0.id == row.value?.id })
            else { return }
            
            self.editNode(node)
        }
        
        return row
    }
    
    private func presentEditor(forNode node: Node?) {
        let editor = screensFactory.makeNodeEditor()
        
        editor.delegate = self
        editor.node = node
        if UIScreen.main.traitCollection.userInterfaceIdiom == .pad {
            self.navigationController?.pushViewController(editor, animated: true)
        } else {
            let navigator = UINavigationController(rootViewController: editor)
            navigator.modalPresentationStyle = .overFullScreen
            present(navigator, animated: true, completion: nil)
        }
    }
    
    private func generateRandomTag() -> String {
        let capacity = 6
        var nums: [UInt32] = []
        nums.reserveCapacity(capacity)
        
        for _ in 0...capacity {
            nums.append(arc4random_uniform(10))
        }
        
        return nums.compactMap { String($0) }.joined()
    }
    
    private func setHealthCheckTimer() {
        timerSubsctiption = Timer
            .publish(every: nodeGroup.crucialUpdateInterval, on: .main, in: .default)
            .autoconnect()
            .sink { [apiService] _ in apiService.healthCheck() }
    }
    
    private func makeNodeCellModel(node: Node) -> NodeCell.Model {
        let connectionStatus = node.isEnabled
            ? node.connectionStatus
            : .none
        
        return .init(
            id: node.id,
            title: node.asString(),
            connectionStatus: connectionStatus,
            statusString: node.statusString(connectionStatus),
            versionString: node.versionString,
            isEnabled: node.isEnabled,
            activities: .init([
                currentRestNodesIds.contains(node.id)
                    ? .rest(scheme: node.scheme)
                    : nil,
                currentSocketsNodeId == node.id
                    ? .webSockets
                    : nil
            ].compactMap { $0 }),
            nodeUpdateAction: .init(id: node.id.uuidString) { [nodesStorage] isEnabled in
                nodesStorage.updateNodeParams(id: node.id, isEnabled: isEnabled)
            }
        )
    }
    
    private func makeNodeCellPublisher(nodeId: UUID) -> some Observable<NodeCell.Model> {
        $nodesList.combineLatest(
            $currentSocketsNodeId,
            $currentRestNodesIds
        ).compactMap { [weak self] tuple in
            let nodes = tuple.0
            
            guard
                let self = self,
                let node = nodes.first(where: { $0.id == nodeId })
            else { return nil }
            
            return self.makeNodeCellModel(node: node)
        }
    }
}

private extension Node {
    func statusString(_ status: Node.ConnectionStatus?) -> String? {
        switch status {
        case .allowed:
            let ping = ping.map { Int($0 * 1000) }
            return ping.map { "\(NodeCell.Strings.ping): \($0) \(NodeCell.Strings.milliseconds)" }
        case .synchronizing:
            return NodeCell.Strings.synchronizing
        case .offline:
            return NodeCell.Strings.offline
        case .none:
            return nil
        }
    }
    
    var versionString: String? {
        version.map { "(\(NodeCell.Strings.version): \($0))" }
    }
}

private extension NodeCell {
    enum Strings {
        static let ping = String.localized(
            "NodesList.NodeCell.Ping",
            comment: "NodesList.NodeCell: Node ping"
        )
        
        static let milliseconds = String.localized(
            "NodesList.NodeCell.Milliseconds",
            comment: "NodesList.NodeCell: Milliseconds"
        )
        
        static let synchronizing = String.localized(
            "NodesList.NodeCell.Synchronizing",
            comment: "NodesList.NodeCell: Node is synchronizing"
        )
        
        static let offline = String.localized(
            "NodesList.NodeCell.Offline",
            comment: "NodesList.NodeCell: Node is offline"
        )
        
        static let version = String.localized(
            "NodesList.NodeCell.Version",
            comment: "NodesList.NodeCell: Node version"
        )
    }
}

private let nodeGroup: NodeGroup = .adm
