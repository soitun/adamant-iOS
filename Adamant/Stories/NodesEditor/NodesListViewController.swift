//
//  NodesListViewController.swift
//  Adamant
//
//  Created by Anton Boyarkin on 13/06/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka


// MARK: - Localization
extension String.adamantLocalized {
    struct nodesList {
        static let title = NSLocalizedString("NodesList.Title", comment: "NodesList: scene title")
        static let nodesListButton = NSLocalizedString("NodesList.NodesList", comment: "NodesList: Button label")
        
        static let defaultNodesWasLoaded = NSLocalizedString("NodeList.DefaultNodesLoaded", comment: "NodeList: Inform that default nodes was loaded, if user deleted all nodes")
        
        static let resetAlertTitle = NSLocalizedString("NodesList.ResetNodeListAlert", comment: "NodesList: Reset nodes alert title")
        
        private init() {}
    }
}


// MARK: - NodesListViewController
class NodesListViewController: FormViewController {
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
                return NSLocalizedString("NodesList.AddNewNode", comment: "NodesList: 'Add new node' button lable")
                
            case .save:
                return String.adamantLocalized.alert.save
                
            case .reset:
                return NSLocalizedString("NodesList.ResetButton", comment: "NodesList: 'Reset' button")
                
            case .preferTheFastestNode:
                return NSLocalizedString("NodesList.PreferTheFastestNode", comment: "NodesList: 'Prefer the fastest node' switch")
            }
        }
    }
    
    // MARK: Dependencies
    
    var dialogService: DialogService!
    var securedStore: SecuredStore!
    var apiService: ApiService!
    var router: Router!
    var nodesSource: NodesSource!
    
    // Properties
    
    private var timer: Timer?
    
    // MARK: - Lifecycle
    
    init() {
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func setup() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name.NodesSource.nodesChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.onMainAsync {
                self?.updateNodesRows()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = String.adamantLocalized.nodesList.title
        navigationOptions = .Disabled
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .always
        }
        
        if splitViewController == nil, navigationController?.viewControllers.count == 1 {
            let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(NodesListViewController.close))
            navigationItem.rightBarButtonItem = done
        }
        
        
        // MARK: Nodes
        
        form +++ Section() {
            $0.tag = Sections.nodes.tag
        }
        
        // MARK: Prefer the fastest node
        
        +++ Section() {
            $0.tag = Sections.preferTheFastestNode.tag
        }
        
        <<< SwitchRow() { [preferTheFastestNode = nodesSource.preferTheFastestNode] in
            $0.title = Rows.preferTheFastestNode.localized
            $0.value = preferTheFastestNode
        }.onChange { [weak nodesSource] in
            nodesSource?.preferTheFastestNode = $0.value ?? true
        }
        
        // MARK: Buttons
        
        +++ Section() {
            $0.tag = Sections.buttons.tag
        }
        
        // Add node
        <<< ButtonRow() {
            $0.title = Rows.addNode.localized
        }.cellSetup { (cell, _) in
            cell.selectionStyle = .gray
        }.onCellSelection { [weak self] (_, _) in
            self?.createNewNode()
        }
            
        // Reset
        <<< ButtonRow() {
            $0.title = Rows.reset.localized
        }.onCellSelection { [weak self] (_, _) in
            self?.resetToDefault()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNodesRows()
        nodesSource.healthCheck()
        setHealthCheckTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
}


// MARK: - Manipulating node list
extension NodesListViewController {
    func createNewNode() {
        presentEditor(forNode: nil)
    }
    
    func addNode(node: Node) {
        getNodesSection()?.append(createRowFor(node: node, tag: generateRandomTag()))
        nodesSource.nodes.append(node)
    }
    
    func removeNode(node: Node) {
        guard let index = getNodeIndex(node: node) else { return }
        
        getNodesSection()?.remove(at: index)
        nodesSource.nodes.remove(at: index)
    }
    
    func getNodeIndex(node: Node) -> Int? {
        nodesSource.nodes.firstIndex { $0 === node }
    }
    
    func getNodesSection() -> Section? {
        form.sectionBy(tag: Sections.nodes.tag)
    }
    
    var displayedNodes: [Node] {
        getNodesSection()?.allRows.compactMap {
            ($0.baseValue as? NodeCell.Model)?.node
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
            nodesSource.setDefaultNodes()
            return
        }
        
        let alert = UIAlertController(title: String.adamantLocalized.nodesList.resetAlertTitle, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(
            title: Rows.reset.localized,
            style: .destructive,
            handler: { [weak self] _ in self?.nodesSource.setDefaultNodes() }
        ))
        alert.modalPresentationStyle = .overFullScreen
        present(alert, animated: true, completion: nil)
    }
    
    func updateNodesRows() {
        guard let nodesSection = getNodesSection() else { return }

        guard displayedNodes != nodesSource.nodes else {
            nodesSection.allRows.forEach { $0.updateCell() }
            return
        }
        
        nodesSection.removeAll()
        
        for node in nodesSource.nodes {
            let row = createRowFor(node: node, tag: generateRandomTag())
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
            removeNode(node: editorNode)
        
        case .nodeUpdated:
            nodesSource.nodesChanged()
        
        case .cancel:
            break
        }
        
        DispatchQueue.main.async {
            if UIScreen.main.traitCollection.userInterfaceIdiom == .pad {
                self.navigationController?.popToViewController(self, animated: true)
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}


// MARK: - Loading nodes

extension NodesListViewController {
    func loadDefaultNodes(showAlert: Bool) {
        nodesSource.setDefaultNodes()
        
        if showAlert {
            dialogService.showSuccess(withMessage: String.adamantLocalized.nodesList.defaultNodesWasLoaded)
        }
    }
}


// MARK: - Tools
extension NodesListViewController {
    private func createRowFor(node: Node, tag: String) -> BaseRow {
        let row = NodeRow() {
            $0.value = makeNodeCellModel(node: node)
            $0.tag = tag
            
            let deleteAction = SwipeAction(
                style: .destructive,
                title: "Delete"
            ) { [weak self] _, row, completionHandler in
                defer { completionHandler?(true) }
                
                guard let model = row.baseValue as? NodeCell.Model else { return }
                self?.removeNode(node: model.node)
            }
            
            $0.trailingSwipe.actions = [deleteAction]
            
            if #available(iOS 11,*) {
                $0.trailingSwipe.performsFirstActionWithFullSwipe = true
            }
        }.cellUpdate { (cell, _) in
            if let label = cell.textLabel {
                label.textColor = UIColor.adamant.primary
            }
        }.onCellSelection { [weak self] (_, row) in
            defer { row.deselect(animated: true) }
            guard let node = row.value?.node else {
                return
            }
            
            self?.editNode(node)
        }
        
        return row
    }
    
    private func presentEditor(forNode node: Node?) {
        guard let editor = router.get(scene: AdamantScene.NodesEditor.nodeEditor) as? NodeEditorViewController else {
            fatalError("Failed to get editor")
        }
        
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
        timer = Timer.scheduledTimer(
            withTimeInterval: regularHealthCheckTimeInteval,
            repeats: true
        ) { [weak nodesSource] _ in
            nodesSource?.healthCheck()
        }
    }
    
    private func makeNodeCellModel(node: Node) -> NodeCell.Model {
        NodeCell.Model(
            node: node,
            setIsEnabled: { [weak nodesSource] isEnabled in
                guard
                    let nodes = nodesSource?.nodes,
                    isEnabled || nodes.filter({ $0.isEnabled }).count > 1
                else { return }
                
                node.isEnabled = isEnabled
                nodesSource?.nodesChanged()
            }
        )
    }
}

private let regularHealthCheckTimeInteval: TimeInterval = 10
