//
//  DashApiService.swift
//  Adamant
//
//  Created by Andrew G on 17.11.2023.
//  Copyright © 2023 Adamant. All rights reserved.
//

import CommonKit
import Foundation

final class DashApiCore: BlockchainHealthCheckableService, Sendable {
    let apiCore: APICoreProtocol

    init(apiCore: APICoreProtocol) {
        self.apiCore = apiCore
    }
    
    func request<Output>(
        origin: NodeOrigin,
        _ request: @Sendable @escaping (APICoreProtocol, NodeOrigin) async -> ApiServiceResult<Output>
    ) async -> WalletServiceResult<Output> {
        await request(apiCore, origin).mapError { $0.asWalletServiceError() }
    }

    func getStatusInfo(origin: NodeOrigin) async -> WalletServiceResult<NodeStatusInfo> {
        let startTimestamp = Date.now.timeIntervalSince1970
        
        let response = await apiCore.sendRequestRPC(
            origin: origin,
            path: .empty,
            requests: [
                .init(method: DashApiComand.networkInfoMethod),
                .init(method: DashApiComand.blockchainInfoMethod)
            ]
        )
        
        guard case let .success(data) = response else {
            return .failure(.internalError(.parsingFailed))
        }
        
        let networkInfoModel = data.first(
            where: { $0.id == DashApiComand.networkInfoMethod }
        )
        
        let blockchainInfoModel = data.first(
            where: { $0.id == DashApiComand.blockchainInfoMethod }
        )
        
        guard
            let networkInfo: DashNetworkInfoDTO = networkInfoModel?.serialize(),
            let blockchainInfo: DashBlockchainInfoDTO = blockchainInfoModel?.serialize()
        else {
            return .failure(.internalError(.parsingFailed))
        }
        
        return .success(.init(
            ping: Date.now.timeIntervalSince1970 - startTimestamp,
            height: blockchainInfo.blocks,
            wsEnabled: false,
            wsPort: nil,
            version: .init(networkInfo.buildversion)
        ))
    }
}

final class DashApiService: ApiServiceProtocol {
    let api: BlockchainHealthCheckWrapper<DashApiCore>
    
    @MainActor
    var nodesInfoPublisher: AnyObservable<NodesListInfo> { api.nodesInfoPublisher }
    
    @MainActor
    var nodesInfo: NodesListInfo { api.nodesInfo }
    
    func healthCheck() { api.healthCheck() }
    
    init(api: BlockchainHealthCheckWrapper<DashApiCore>) {
        self.api = api
    }
    
    func request<Output>(
        waitsForConnectivity: Bool,
        _ request: @Sendable @escaping (APICoreProtocol, NodeOrigin) async -> ApiServiceResult<Output>
    ) async -> WalletServiceResult<Output> {
        await api.request(waitsForConnectivity: waitsForConnectivity) { core, origin in
            await core.request(origin: origin, request)
        }
    }
    
    func getStatusInfo() async -> WalletServiceResult<NodeStatusInfo> {
        await api.request(waitsForConnectivity: false) { core, origin in
            await core.getStatusInfo(origin: origin)
        }
    }
}
