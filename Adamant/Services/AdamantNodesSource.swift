//
//  AdamantNodesSource.swift
//  Adamant
//
//  Created by Anokhov Pavel on 21.06.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

class AdamantNodesSource: NodesSource {
    // MARK: - Dependencies
    
    var apiService: ApiService!
    
    var healthCheckService: HealthCheckService! {
        didSet {
            healthCheckService.delegate = self
            healthCheckService.nodes = nodes
            setHealthCheckTimer()
        }
    }
    
    var securedStore: SecuredStore! {
        didSet {
            loadNodes()
        }
    }
    
    // MARK: - Properties
    
    var nodes: [Node] = [] {
        didSet {
            healthCheckService.nodes = nodes
            nodesUpdate()
        }
    }
    
    var preferTheFastestNode = preferTheFastestNodeDefault {
        didSet {
            savePreferTheFastestNode(preferTheFastestNode)
            
            guard preferTheFastestNode else { return }
            sendNodesUpdateNotification()
        }
    }
    
    private let defaultNodesGetter: () -> [Node]
    private var timer: Timer?
    
    // MARK: - Ctor
    
    init(defaultNodesGetter: @escaping () -> [Node]) {
        self.defaultNodesGetter = defaultNodesGetter
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name.AdamantReachabilityMonitor.reachabilityChanged,
            object: nil,
            queue: nil
        ) { [weak healthCheckService] notification in
            let connection = notification.userInfo?[
                AdamantUserInfoKey.ReachabilityMonitor.connection
            ] as? AdamantConnection
            
            switch connection {
            case .wifi, .cellular:
                healthCheckService?.healthCheck()
            case nil, .some(.none):
                break
            }
        }
        
        guard
            let preferTheFastestNode = UserDefaults.standard.object(
                forKey: UserDefaults.NodesSource.preferTheFastestNodeKey
            ) as? Bool
        else {
            savePreferTheFastestNode(preferTheFastestNodeDefault)
            return
        }
        
        self.preferTheFastestNode = preferTheFastestNode
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Tools
    
    func setDefaultNodes() {
        nodes = defaultNodesGetter()
    }
    
    func getPreferredNode(needWS: Bool) -> Node? {
        healthCheckService?.getPreferredNode(fastest: preferTheFastestNode, needWS: needWS)
    }
    
    func nodesUpdate() {
        migrate()
        healthCheckService.healthCheck()
        saveNodes()
    }
    
    func healthCheck() {
        healthCheckService.healthCheck()
    }
    
    private func savePreferTheFastestNode(_ newValue: Bool) {
        UserDefaults.standard.set(
            newValue,
            forKey: UserDefaults.NodesSource.preferTheFastestNodeKey
        )
    }
    
    private func sendNodesUpdateNotification() {
        NotificationCenter.default.post(
            name: Notification.Name.NodesSource.nodesUpdate,
            object: self,
            userInfo: [:]
        )
    }
    
    private func migrate() {
        nodes.forEach { node in
            if node.host == "185.231.245.26", node.port == 36666 {
                node.host = "23.226.231.225"
            }
        }
    }
    
    private func saveNodes() {
        do {
            let data = try JSONEncoder().encode(nodes)
            guard let raw = String(data: data, encoding: String.Encoding.utf8) else {
                return
            }
            
            securedStore.set(raw, for: StoreKey.NodesSource.nodes)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func loadNodes() {
        guard let raw = securedStore.get(StoreKey.NodesSource.nodes), let data = raw.data(using: String.Encoding.utf8) else {
            nodes = defaultNodesGetter()
            return
        }
        
        do {
            nodes = try JSONDecoder().decode([Node].self, from: data)
        } catch {
            nodes = defaultNodesGetter()
            print(error.localizedDescription)
        }
    }
    
    private func setHealthCheckTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: regularHealthCheckTimeInteval,
            repeats: true
        ) { [weak healthCheckService] _ in
            healthCheckService?.healthCheck()
        }
    }
}

extension AdamantNodesSource: HealthCheckDelegate {
    func healthCheckUpdate() {
        sendNodesUpdateNotification()
    }
}

private let regularHealthCheckTimeInteval: TimeInterval = 300
private let preferTheFastestNodeDefault = true
