//
//  LayoutBreakpoint.swift
//  social wand
//
//  Created by Codex on 11/17/25.
//

import SwiftUI

enum LayoutBreakpoint {
    case veryCompact
    case compact
    case regular

    static func forHeight(_ height: CGFloat) -> LayoutBreakpoint {
        if height < 520 {
            return .veryCompact
        } else if height < 780 {
            return .compact
        } else {
            return .regular
        }
    }
}
