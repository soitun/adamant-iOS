//
//  StorageUsageFactory.swift
//  Adamant
//
//  Created by Stanislav Jelezoglo on 27.03.2024.
//  Copyright © 2024 Adamant. All rights reserved.
//

import Swinject
import SwiftUI
import FilesStorageKit

@MainActor
struct StorageUsageFactory {
    private let assembler: Assembler
    
    init(parent: Assembler) {
        assembler = .init([StorageUsageAssembly()], parent: parent)
    }
    
    func makeViewController() -> UIViewController {
        UIHostingController(
            rootView: StorageUsageView {
                assembler.resolve(StorageUsageViewModel.self)!
            }
        )
    }
}

private struct StorageUsageAssembly: MainThreadAssembly {
    func assembleOnMainThread(container: Container) {
        container.register(StorageUsageViewModel.self) {
            StorageUsageViewModel(
                filesStorage: $0.resolve(FilesStorageProtocol.self)!,
                dialogService: $0.resolve(DialogService.self)!, 
                filesStorageProprieties: $0.resolve(FilesStorageProprietiesProtocol.self)!
            )
        }.inObjectScope(.weak)
    }
}
