//
//  Message.swift
//  OneField
//
//  Created by Danna Valencia on 04/10/25.
//

import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}
