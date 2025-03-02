//
//  IPFSApiService.swift
//  Adamant
//
//  Created by Stanislav Jelezoglo on 09.04.2024.
//  Copyright © 2024 Adamant. All rights reserved.
//

import Foundation
import CommonKit

enum IPFSApiCommands {
    static let file = (
        upload: "api/file/upload",
        download: "api/file/",
        fieldName: "files"
    )
}

final class IPFSApiService: FileApiServiceProtocol {
    let service: BlockchainHealthCheckWrapper<IPFSApiCore>
    
    @MainActor
    var nodesInfoPublisher: AnyObservable<NodesListInfo> { service.nodesInfoPublisher }
    
    @MainActor
    var nodesInfo: NodesListInfo { service.nodesInfo }
    
    func healthCheck() { service.healthCheck() }
    
    init(
        healthCheckWrapper: BlockchainHealthCheckWrapper<IPFSApiCore>
    ) {
        service = healthCheckWrapper
    }
    
    func request<Output>(
        _ request: @Sendable (APICoreProtocol, NodeOrigin) async -> ApiServiceResult<Output>
    ) async -> ApiServiceResult<Output> {
        await service.request(waitsForConnectivity: false) { admApiCore, node in
            await request(admApiCore.apiCore, node)
        }
    }
    
    func uploadFile(
        data: Data,
        uploadProgress: @escaping @Sendable (Progress) -> Void
    ) async -> FileApiServiceResult<String> {
        let model: MultipartFormDataModel = .init(
            keyName: IPFSApiCommands.file.fieldName,
            fileName: defaultFileName,
            data: data
        )
        
        let result: Result<IpfsDTO, ApiServiceError> = await request { core, origin in
            await core.sendRequestMultipartFormDataJsonResponse(
                origin: origin,
                path: IPFSApiCommands.file.upload,
                models: [model],
                timeout: .extended,
                uploadProgress: uploadProgress
            )
        }
        
        return result.flatMap { result in
            guard let cid = result.cids.first else {
                return .failure(
                    .serverError(error: FileManagerError.cantUploadFile.localizedDescription)
                )
            }
            
            return .success(cid)
        }.mapError { .apiError(error: $0) }
    }
    
    func downloadFile(
        id: String,
        downloadProgress: @escaping @Sendable (Progress) -> Void
    ) async -> FileApiServiceResult<Data> {
        let result: Result<Data, ApiServiceError> = await request { core, origin in
            let result: APIResponseModel = await core.sendRequest(
                origin: origin,
                path: "\(IPFSApiCommands.file.download)\(id)",
                timeout: .extended,
                downloadProgress: downloadProgress
            )
            
            if let error = handleError(result) {
                return .failure(error)
            }
            
            return result.result
        }
        
        return result.flatMap { .success($0) }
            .mapError { .apiError(error: $0) }
    }
}

private extension IPFSApiService {
    func handleError(_ result: APIResponseModel) -> ApiServiceError? {
        guard let code = result.code,
              !(200 ... 299).contains(code)
        else { return nil }
        
        let serverError = ApiServiceError.serverError(error: "\(code)")
        let error = code == 500 || code == 502 || code == 504
        ? .networkError(error: serverError)
        : serverError
        
        return error
    }
}

private let defaultFileName = "fileName"
