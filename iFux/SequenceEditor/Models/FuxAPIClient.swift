//
//  FuxAPIClient.swift
//  iFux
//
//  Created on 30.03.26.
//

import Foundation
import UIKit

// MARK: - API Response Models

struct EffectsResponse: Codable {
    let effects: [APIEffect]
}

struct APIEffect: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let algorithm: String
    let type: String
    let fps: Int?
    let parameters: [EffectParameter]?
    let tags: [String]?
    let version: String?

    static func == (lhs: APIEffect, rhs: APIEffect) -> Bool {
        lhs.id == rhs.id
    }
}

struct EffectParameter: Codable, Identifiable {
    let name: String
    let type: String
    let defaultValue: AnyCodable?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, type
        case defaultValue = "default"
    }
}

// MARK: - AnyCodable (lightweight wrapper for mixed-type JSON values)

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let strVal = try? container.decode(String.self) {
            value = strVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let arrVal = try? container.decode([AnyCodable].self) {
            value = arrVal.map { $0.value }
        } else {
            value = "unknown"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let v = value as? Int { try container.encode(v) }
        else if let v = value as? Double { try container.encode(v) }
        else if let v = value as? String { try container.encode(v) }
        else if let v = value as? Bool { try container.encode(v) }
        else { try container.encode("\(value)") }
    }

    var displayString: String {
        if let arr = value as? [Any] {
            return arr.map { "\($0)" }.joined(separator: ", ")
        }
        return "\(value)"
    }
}

// MARK: - Preview Request

struct PreviewRequest: Encodable {
    let effect: String
    let duration: Int
    let width: Int
    let height: Int
}

// MARK: - FuxAPIClient

class FuxAPIClient {
    private let session: URLSession
    private let previewCache = NSCache<NSString, UIImage>()
    private var baseURL: String

    init(host: String = "192.168.1.96", port: Int = 8080) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
        self.baseURL = "http://\(host):\(port)"
        previewCache.countLimit = 50
    }

    func updateHost(_ host: String, port: Int = 8080) {
        self.baseURL = "http://\(host):\(port)"
    }

    // MARK: - Fetch Effects

    func fetchEffects() async throws -> [APIEffect] {
        guard let url = URL(string: "\(baseURL)/api/effects") else {
            throw FuxAPIError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FuxAPIError.serverError
        }
        let decoded = try JSONDecoder().decode(EffectsResponse.self, from: data)
        return decoded.effects
    }

    // MARK: - Fetch Effect Detail

    func fetchEffect(named name: String) async throws -> APIEffect {
        guard let url = URL(string: "\(baseURL)/api/effects/\(name)") else {
            throw FuxAPIError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FuxAPIError.serverError
        }
        return try JSONDecoder().decode(APIEffect.self, from: data)
    }

    // MARK: - Fetch Preview GIF

    func fetchPreview(for effectName: String) async throws -> UIImage {
        let cacheKey = NSString(string: effectName)
        if let cached = previewCache.object(forKey: cacheKey) {
            return cached
        }

        guard let url = URL(string: "\(baseURL)/api/preview") else {
            throw FuxAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = PreviewRequest(effect: effectName, duration: 2, width: 268, height: 1)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FuxAPIError.serverError
        }

        guard let animatedImage = UIImage.animatedGIF(from: data) else {
            throw FuxAPIError.invalidData
        }

        previewCache.setObject(animatedImage, forKey: cacheKey)
        return animatedImage
    }

    func clearPreviewCache() {
        previewCache.removeAllObjects()
    }
}

// MARK: - Errors

enum FuxAPIError: LocalizedError {
    case invalidURL
    case serverError
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .serverError: return "Server returned an error"
        case .invalidData: return "Could not parse response"
        }
    }
}

// MARK: - UIImage GIF Support

extension UIImage {
    static func animatedGIF(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            // Single frame – return as static image
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }

        var images: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))

            // Extract frame duration from GIF properties
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifDict = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                if let delay = gifDict[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
                    totalDuration += delay
                } else if let delay = gifDict[kCGImagePropertyGIFDelayTime as String] as? Double {
                    totalDuration += delay
                } else {
                    totalDuration += 0.1
                }
            } else {
                totalDuration += 0.1
            }
        }

        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}
