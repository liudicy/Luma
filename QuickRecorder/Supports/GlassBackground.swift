//
//  GlassBackground.swift
//  QuickRecorder
//
//  Liquid Glass background extension for macOS 26+ with fallback for older versions.
//

import SwiftUI

extension View {
    @ViewBuilder
    func qrGlassBackground(tint: Color? = nil, cornerRadius: CGFloat = 8, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            // NOTE: verified .interactive() IS available on the macOS 26+ SDK (target arm64-apple-macos26.0).
            if let tint = tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                }
            }
        } else {
            if let tint = tint {
                self.background(tint.opacity(0.8)).cornerRadius(cornerRadius)
            } else {
                self.background(.ultraThinMaterial).cornerRadius(cornerRadius)
            }
        }
    }
}
