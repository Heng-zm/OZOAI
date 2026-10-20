import Foundation
import SwiftUI

struct AIModel: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let vendor: String
    let tagline: String
    let symbol: String
    let tintHex: UInt32
    let supportsVision: Bool
    let badges: [String]

    var tint: Color { Color(hex: tintHex) }
    var isFree: Bool { true }
    var showsFreeBadge: Bool { !name.localizedCaseInsensitiveContains("free") }

    static let defaultID = "glm-5.3-flash-free"

    static let all: [AIModel] = [
        AIModel(
            id: "big-pickle",
            name: "Big Pickle",
            shortName: "Big Pickle",
            vendor: "Stealth model",
            tagline: "A clever wildcard for creative, out-of-the-box thinking.",
            symbol: "sparkles",
            tintHex: 0xF59E0B,
            supportsVision: false,
            badges: ["Creative", "Reasoning"]
        ),
        AIModel(
            id: "deepseek-v4.1-flash-free",
            name: "DeepSeek V4.1 Flash Free",
            shortName: "DeepSeek V4.1 Flash",
            vendor: "DeepSeek",
            tagline: "Deep reasoning and strong coding at flash speed.",
            symbol: "brain.head.profile",
            tintHex: 0x3B82F6,
            supportsVision: false,
            badges: ["Reasoning", "Code"]
        ),
        AIModel(
            id: "glm-5.3-flash-free",
            name: "GLM-5.3-Flash Free",
            shortName: "GLM-5.3-Flash",
            vendor: "Z.ai",
            tagline: "The balanced everyday model: fast, sharp and reliable.",
            symbol: "bolt.fill",
            tintHex: 0x10B981,
            supportsVision: false,
            badges: ["Fast", "All-rounder"]
        ),
        AIModel(
            id: "minimax-m3.1-flash-free",
            name: "MiniMax M3.1 Flash Free",
            shortName: "MiniMax M3.1 Flash",
            vendor: "MiniMax",
            tagline: "Quick, expressive answers for everyday conversations.",
            symbol: "circle.hexagongrid.fill",
            tintHex: 0xEC4899,
            supportsVision: false,
            badges: ["Fast"]
        ),
        AIModel(
            id: "nemotron-3.5-super-vl-free",
            name: "Nemotron 3.5 Super VL Free",
            shortName: "Nemotron 3.5 Super VL",
            vendor: "NVIDIA",
            tagline: "Vision-language model. Send photos, screenshots and diagrams.",
            symbol: "eye.fill",
            tintHex: 0x8B5CF6,
            supportsVision: true,
            badges: ["Vision", "Reasoning"]
        ),
        AIModel(
            id: "beam-free",
            name: "Beam Free",
            shortName: "Beam",
            vendor: "Beam",
            tagline: "Ultra-light replies for quick questions on the go.",
            symbol: "wind",
            tintHex: 0x06B6D4,
            supportsVision: false,
            badges: ["Fastest"]
        ),
        AIModel(
            id: "longcat-2.5-preview-free",
            name: "LongCat 2.5 Preview Free",
            shortName: "LongCat 2.5 Preview",
            vendor: "Meituan",
            tagline: "Comfortable with long documents, notes and big pasted text.",
            symbol: "text.alignleft",
            tintHex: 0x6366F1,
            supportsVision: false,
            badges: ["Long context"]
        ),
        AIModel(
            id: "mimo-v2.6-flash-free",
            name: "MiMo-V2.6-Flash Free",
            shortName: "MiMo-V2.6-Flash",
            vendor: "Xiaomi",
            tagline: "Efficient mobile-scale model with snappy, useful answers.",
            symbol: "hare.fill",
            tintHex: 0xF97316,
            supportsVision: false,
            badges: ["Fast", "Efficient"]
        ),
        AIModel(
            id: "nemotron-3.5-lightning-free",
            name: "Nemotron 3.5 Lightning Free",
            shortName: "Nemotron 3.5 Lightning",
            vendor: "NVIDIA",
            tagline: "Low-latency model built for rapid back-and-forth.",
            symbol: "waveform",
            tintHex: 0xEAB308,
            supportsVision: false,
            badges: ["Fast"]
        ),
        AIModel(
            id: "nemotron-3-ultra-free",
            name: "Nemotron 3 Ultra Free",
            shortName: "Nemotron 3 Ultra",
            vendor: "NVIDIA",
            tagline: "Flagship reasoning power for hard problems and big code.",
            symbol: "cpu",
            tintHex: 0x14B8A6,
            supportsVision: false,
            badges: ["Flagship", "Reasoning"]
        ),
        AIModel(
            id: "claude-fable-5-1",
            name: "Claude Fable 5.1",
            shortName: "Claude Fable 5.1",
            vendor: "Anthropic",
            tagline: "Frontier reasoning for ambitious, long-running work.",
            symbol: "wand.and.stars",
            tintHex: 0xD97706,
            supportsVision: true,
            badges: ["Frontier", "Reasoning"]
        ),
        AIModel(
            id: "claude-opus-5-5",
            name: "Claude Opus 5.5",
            shortName: "Claude Opus 5.5",
            vendor: "Anthropic",
            tagline: "Deep intelligence for coding, research and hard problems.",
            symbol: "crown.fill",
            tintHex: 0x9333EA,
            supportsVision: true,
            badges: ["Flagship", "Code"]
        ),
        AIModel(
            id: "claude-sonnet-5-5",
            name: "Claude Sonnet 5.5",
            shortName: "Claude Sonnet 5.5",
            vendor: "Anthropic",
            tagline: "The best balance of speed and intelligence for everyday work.",
            symbol: "sparkle",
            tintHex: 0xEA580C,
            supportsVision: true,
            badges: ["Best value", "Vision"]
        ),
        AIModel(
            id: "claude-haiku-5-5",
            name: "Claude Haiku 5.5",
            shortName: "Claude Haiku 5.5",
            vendor: "Anthropic",
            tagline: "Fastest Claude for quick answers and high-volume tasks.",
            symbol: "wind",
            tintHex: 0x0891B2,
            supportsVision: true,
            badges: ["Fastest", "Vision"]
        )
    ]

    static let visionModelID = "nemotron-3.5-super-vl-free"

    static func model(for id: String) -> AIModel {
        all.first(where: { $0.id == id })
            ?? all.first(where: { $0.id == defaultID })
            ?? all[0]
    }
}
