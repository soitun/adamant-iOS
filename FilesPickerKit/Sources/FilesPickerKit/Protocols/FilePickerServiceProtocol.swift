//
//  File.swift
//  
//
//  Created by Stanislav Jelezoglo on 11.02.2024.
//

import UIKit
import CommonKit

@MainActor
protocol FilePickerServiceProtocol {
    var onPreparedDataCallback: ((Result<[FileResult], Error>) -> Void)? { get set }
    var onPreparingDataCallback: (() -> Void)? { get set }
}
