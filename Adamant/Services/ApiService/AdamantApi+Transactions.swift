//
//  AdamantApi+Transactions.swift
//  Adamant
//
//  Created by Anokhov Pavel on 24.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import CommonKit

extension ApiCommands {
    static let Transactions = (
        root: "/api/transactions",
        getTransaction: "/api/transactions/get",
        normalizeTransaction: "/api/transactions/normalize",
        processTransaction: "/api/transactions/process"
    )
}

extension AdamantApiService {
    func sendTransaction(
        path: String,
        transaction: UnregisteredTransaction
    ) async -> ApiServiceResult<UInt64> {
        let response: ApiServiceResult<TransactionIdResponse> = await request { core, node in
            await core.sendRequestJson(
                node: node,
                path: path,
                method: .post,
                parameters: ["transaction": transaction],
                encoding: .json
            )
        }
        
        return response.flatMap { $0.resolved() }
    }
    
    func sendDelegateVoteTransaction(
        path: String,
        transaction: UnregisteredTransaction
    ) async -> ApiServiceResult<UInt64> {
        let response: ApiServiceResult<TransactionIdResponse> = await request { core, node in
            await core.sendRequestJson(
                node: node,
                path: path,
                method: .post,
                parameters: transaction,
                encoding: .json
            )
        }
        
        return response.flatMap { $0.resolved() }
    }
    
    func getTransaction(id: UInt64) async -> ApiServiceResult<Transaction> {
        await getTransaction(id: id, withAsset: false)
    }
    
    func getTransaction(id: UInt64, withAsset: Bool) async -> ApiServiceResult<Transaction> {
        let response: ApiServiceResult<ServerModelResponse<Transaction>>
        response = await request { core, node in
            await core.sendRequestJson(
                node: node,
                path: ApiCommands.Transactions.getTransaction,
                method: .get,
                parameters: [
                    "id": String(id),
                    "returnAsset": withAsset ? "1" : "0"
                ],
                encoding: .url
            )
        }
        
        return response.flatMap { $0.resolved() }
    }
    
    func getTransactions(
        forAccount account: String,
        type: TransactionType,
        fromHeight: Int64?,
        offset: Int?,
        limit: Int?
    ) async -> ApiServiceResult<[Transaction]> {
        await getTransactions(
            forAccount: account,
            type: type,
            fromHeight: fromHeight,
            offset: offset,
            limit: limit,
            orderByTime: false
        )
    }
    
    func getTransactions(
        forAccount account: String,
        type: TransactionType,
        fromHeight: Int64?,
        offset: Int?,
        limit: Int?,
        orderByTime: Bool?
    ) async -> ApiServiceResult<[Transaction]> {
        var queryItems = [URLQueryItem(name: "inId", value: account)]
        
        if type == .send {
            // transfers can be of type 0 and 8 so we can filter by min amount
            queryItems.append(URLQueryItem(name: "and:minAmount", value: "1"))
        } else {
            queryItems.append(URLQueryItem(name: "and:type", value: String(type.rawValue)))
        }
        
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        if let fromHeight = fromHeight, fromHeight > 0 {
            queryItems.append(URLQueryItem(name: "and:fromHeight", value: String(fromHeight)))
        }
        
        if let orderByTime = orderByTime, orderByTime {
            queryItems.append(URLQueryItem(name: "orderBy", value: "timestamp:desc"))
        }
        
        let response: ApiServiceResult<ServerCollectionResponse<Transaction>>
        response = await request { [queryItems] core, node in
            await core.sendRequestJson(
                node: node,
                path: ApiCommands.Transactions.root,
                method: .get,
                parameters: [Bool](),
                encoding: .forceQueryItems(queryItems)
            )
        }
        
        return response.flatMap { $0.resolved() }
    }
}
