//
//  ControlModel.swift
//  iFux
//
//  Created on 18.03.26.
//

import Foundation

// MARK: - Control Mode Enum
enum ControlMode: String, Codable, CaseIterable {
    case random = "RANDOM"
    case queue = "QUEUE"
    
    var displayName: String {
        switch self {
        case .random:
            return "Random"
        case .queue:
            return "Queue"
        }
    }
}

// MARK: - Effect Model
struct Effect: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let displayName: String
    
    init(id: String, name: String, displayName: String) {
        self.id = id
        self.name = name
        self.displayName = displayName
    }
    
    init(name: String) {
        self.id = name
        self.name = name
        self.displayName = name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Control State
struct ControlState: Codable {
    var mode: ControlMode
    var queue: [String]
    var currentEffect: String?
    
    enum CodingKeys: String, CodingKey {
        case mode
        case queue
        case currentEffect = "current_effect"
    }
}

// MARK: - Available Effects
extension Effect {
    static let availableEffects: [Effect] = [
        Effect(name: "diamond_pulse"),
        Effect(name: "rainbow_pulse"),
        Effect(name: "color_waves"),
        Effect(name: "aurora")
    ]
    
    static func effect(named name: String) -> Effect? {
        return availableEffects.first { $0.name == name }
    }
}
