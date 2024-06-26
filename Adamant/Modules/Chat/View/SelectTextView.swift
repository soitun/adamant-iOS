//
//  SelectTextView.swift
//  Adamant
//
//  Created by Yana Silosieva on 13.02.2024.
//  Copyright © 2024 Adamant. All rights reserved.
//

import Foundation
import SwiftUI

struct SelectTextView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                contentView
            }
        } else {
            NavigationView {
                contentView
            }
        }
    }
    
    var contentView: some View {
        VStack {
            TextView(text: text)
                .accentColor(.blue)
                .padding()
            
            Spacer()
        }
        .navigationBarTitle(String.adamant.chat.selectText, displayMode: .inline)
        .navigationBarItems(
            trailing:
                Button(
                    action: { dismiss() }
                ) {
                    Image(systemName: "xmark")
                }
        )
        .navigationViewStyle(.stack)
    }
}

private struct TextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.text = text
        textView.font = .systemFont(ofSize: 17)
        textView.selectAll(nil)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.text = text
    }
}
