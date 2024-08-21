//
//  ExtensionsApiFactory.swift
//
//
//  Created by Andrew G on 08.08.2024.
//

public struct ExtensionsApiFactory {
    public let core: AdamantCore
    public let securedStore: SecuredStore
    
    public init(core: AdamantCore, securedStore: SecuredStore) {
        self.core = core
        self.securedStore = securedStore
    }
    
    public func make() -> ExtensionsApi {
        .init(apiService: AdamantApiService(
            healthCheckWrapper: .init(
                service: AdamantApiCore(apiCore: APICore()),
                nodesStorage: NodesStorage(
                    securedStore: securedStore,
                    nodesMergingService: AdamantNodesMergingService(),
                    defaultNodes: .init()
                ),
                nodesAdditionalParamsStorage: NodesAdditionalParamsStorage(
                    securedStore: securedStore
                ),
                isActive: false,
                params: .init(
                    group: .adm,
                    name: "ADM",
                    normalUpdateInterval: .infinity,
                    crucialUpdateInterval: .infinity,
                    minNodeVersion: .zero,
                    nodeHeightEpsilon: .zero
                ),
                connection: nil
            ),
            adamantCore: core
        ))
    }
}
