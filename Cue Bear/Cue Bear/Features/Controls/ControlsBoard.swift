//
//  ControlsBoard.swift — Cue Bear Next
//
//  The controls board: the one view of the shared controls (plus the current song's extras).
//  Show plays it; Build edits it in place, so what you build is what you play.
//  - Buttons and toggles flow in rows, Regular (1 unit) or Wide (2 units); faders are full-width rows.
//  - Build: tap selects, hold and drag onto another control moves it there, the + tile adds.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// One thing on the board: a shared control or a song extra.
struct BoardItem: Identifiable, Equatable {
    enum Kind: Equatable { case button, toggle, fader }

    let id: UUID
    var title: String
    var symbol: String
    var kind: Kind
    var isWide: Bool
    var colorHex: String?
    var isOn: Bool
    var value: Double          // faders, 0...1
    var isExtra: Bool          // belongs to the current song only

    init(control c: ControlButton) {
        id = c.id
        title = c.title.isEmpty ? (c.isFader == true ? "Fader" : "Button") : c.title
        symbol = c.symbol
        kind = c.isFader == true ? .fader : (c.isToggle == true ? .toggle : .button)
        isWide = c.isSmall != true
        colorHex = c.colorHex
        isOn = c.isToggle == true && c.toggleState
        value = c.faderValue ?? 0
        isExtra = false
    }

    init(extra e: SongExtra, isOn: Bool, value: Double) {
        id = e.id
        title = e.title
        symbol = e.style == .toggle ? "power" : ""
        switch e.style {
        case .button: kind = .button
        case .toggle: kind = .toggle
        case .fader: kind = .fader
        }
        isWide = false
        colorHex = nil
        self.isOn = isOn
        self.value = value
        isExtra = true
    }
}

struct ControlsBoard: View {
    enum Mode { case play, build }

    let items: [BoardItem]
    var mode: Mode = .play
    var selectedID: UUID? = nil
    var onPress: (BoardItem) -> Void = { _ in }
    var onFader: (BoardItem, Double) -> Void = { _, _ in }
    var onSelect: (UUID) -> Void = { _ in }
    var onMove: (_ moving: UUID, _ before: UUID) -> Void = { _, _ in }
    var onAdd: (_ fader: Bool) -> Void = { _ in }

    private var buttons: [BoardItem] { items.filter { $0.kind != .fader } }
    private var faders: [BoardItem] { items.filter { $0.kind == .fader } }

    var body: some View {
        VStack(alignment: .leading, spacing: CBSpace.m) {
            BoardFlowLayout(unit: 132, rowHeight: 76, spacing: CBSpace.m) {
                ForEach(buttons) { item in
                    tile(for: item)
                        .layoutValue(key: BoardSpanKey.self, value: item.isWide ? 2 : 1)
                }
                if mode == .build {
                    addMenu
                        .layoutValue(key: BoardSpanKey.self, value: 1)
                }
            }
            ForEach(faders) { item in
                faderRow(for: item)
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func tile(for item: BoardItem) -> some View {
        let t = BoardTile(item: item, isSelected: mode == .build && selectedID == item.id) {
            if mode == .build { onSelect(item.id) } else { onPress(item) }
        }
        if mode == .build && !item.isExtra {
            t
                .draggable(item.id.uuidString)
                .dropDestination(for: String.self) { ids, _ in
                    guard let first = ids.first, let moving = UUID(uuidString: first), moving != item.id else { return false }
                    onMove(moving, item.id)
                    return true
                }
        } else {
            t
        }
    }

    @ViewBuilder
    private func faderRow(for item: BoardItem) -> some View {
        let row = BoardFaderRow(item: item, isSelected: mode == .build && selectedID == item.id,
                                isInteractive: mode == .play,
                                onChange: { onFader(item, $0) },
                                onSelect: { onSelect(item.id) })
        if mode == .build && !item.isExtra {
            row
                .draggable(item.id.uuidString)
                .dropDestination(for: String.self) { ids, _ in
                    guard let first = ids.first, let moving = UUID(uuidString: first), moving != item.id else { return false }
                    onMove(moving, item.id)
                    return true
                }
        } else {
            row
        }
    }

    private var addMenu: some View {
        Menu {
            Button(action: { onAdd(false) }) { Label("Button or toggle", systemImage: "square.grid.2x2") }
            Button(action: { onAdd(true) }) { Label("Fader", systemImage: "slider.horizontal.3") }
        } label: {
            VStack(spacing: CBSpace.xs) {
                Image(systemName: "plus").font(.cbIcon(.title))
                Text("Add").font(.cb(.small, .semibold))
            }
            .foregroundStyle(CBColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: CBRadius.card)
                .strokeBorder(CBColor.strokeStrong, style: StrokeStyle(lineWidth: CBSize.hairline, dash: [5, 4])))
            .contentShape(RoundedRectangle(cornerRadius: CBRadius.card))
        }
        .accessibilityLabel("Add a control")
    }
}

// MARK: - Tile

struct BoardTile: View {
    let item: BoardItem
    let isSelected: Bool
    let action: () -> Void

    private var fill: Color {
        if item.isOn { return CBColor.highlight }
        if let hex = item.colorHex, !hex.isEmpty { return Color(hex: hex) }
        return CBColor.surface
    }

    private var ink: Color {
        if item.isOn { return CBColor.onHighlight }
        if let hex = item.colorHex, !hex.isEmpty, Color(hex: hex).needsDarkText() { return .black }
        return CBColor.textPrimary
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: CBSpace.xs) {
                if !item.symbol.isEmpty {
                    Image(systemName: item.symbol).font(.cbIcon(.large))
                }
                Text(item.title)
                    .font(.cb(.body, .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if item.isExtra {
                    CBTag(text: "THIS SONG", color: item.isOn ? CBColor.surfaceRaised : CBColor.highlight)
                } else if item.kind == .toggle {
                    Text(item.isOn ? "ON" : "OFF")
                        .font(.cb(.micro, .bold))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(ink)
            .padding(.horizontal, CBSpace.s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: CBRadius.card).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: CBRadius.card)
                .stroke(borderColor, lineWidth: isSelected || item.isExtra ? CBSize.selection : CBSize.hairline))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.cbIcon(.body))
                        .foregroundStyle(CBColor.highlight, CBColor.onHighlight)
                        .padding(CBSpace.xs)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CBRadius.card))
        }
        .buttonStyle(IOSPressButtonStyle())
        .accessibilityLabel(item.title)
        .accessibilityValue(item.kind == .toggle ? (item.isOn ? "On" : "Off") : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var borderColor: Color {
        if isSelected { return CBColor.textPrimary }
        if item.isExtra { return CBColor.highlight }
        return CBColor.stroke
    }
}

// MARK: - Fader row

struct BoardFaderRow: View {
    let item: BoardItem
    let isSelected: Bool
    let isInteractive: Bool
    var onChange: (Double) -> Void
    var onSelect: () -> Void

    @State private var local: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: CBSpace.xs) {
            HStack(spacing: CBSpace.s) {
                if let hex = item.colorHex, !hex.isEmpty {
                    Circle().fill(Color(hex: hex)).frame(width: 10, height: 10)
                }
                Text(item.title)
                    .font(.cb(.body, .semibold))
                    .foregroundStyle(CBColor.textPrimary)
                if item.isExtra { CBTag(text: "THIS SONG") }
                Spacer()
                Text("\(Int((local * 127).rounded()))")
                    .font(.cbMono(.small))
                    .foregroundStyle(CBColor.textTertiary)
            }
            Slider(value: Binding(get: { local }, set: { v in local = v; onChange(v) }), in: 0...1)
                .tint(CBColor.highlight)
                .disabled(!isInteractive)
                .accessibilityLabel(item.title)
        }
        .cbCard(outline: isSelected ? CBColor.textPrimary : (item.isExtra ? CBColor.highlight : nil), padding: CBSpace.m)
        .contentShape(Rectangle())
        .onTapGesture { if !isInteractive { onSelect() } }
        .onAppear { local = item.value }
        .onChange(of: item.value) { _, v in local = v }
    }
}

// MARK: - Layout

struct BoardSpanKey: LayoutValueKey {
    static let defaultValue: Int = 1
}

/// Rows of tiles, in order. A tile spans 1 or 2 units; a wide tile that doesn't fit starts a new row.
struct BoardFlowLayout: Layout {
    let unit: CGFloat
    let rowHeight: CGFloat
    let spacing: CGFloat

    private func columns(for width: CGFloat) -> Int {
        max(2, Int((width + spacing) / (unit + spacing)))
    }

    private func place(_ subviews: Subviews, width: CGFloat) -> [(col: Int, row: Int, span: Int)] {
        let cols = columns(for: width)
        var result: [(col: Int, row: Int, span: Int)] = []
        var col = 0, row = 0
        for view in subviews {
            let span = min(cols, max(1, view[BoardSpanKey.self]))
            if col + span > cols { col = 0; row += 1 }
            result.append((col, row, span))
            col += span
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (unit * 4 + spacing * 3)
        let rows = (place(subviews, width: width).map(\.row).max() ?? -1) + 1
        let height = rows == 0 ? 0 : CGFloat(rows) * rowHeight + CGFloat(rows - 1) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cols = columns(for: bounds.width)
        let cell = (bounds.width - CGFloat(cols - 1) * spacing) / CGFloat(cols)
        for (view, slot) in zip(subviews, place(subviews, width: bounds.width)) {
            let x = bounds.minX + CGFloat(slot.col) * (cell + spacing)
            let y = bounds.minY + CGFloat(slot.row) * (rowHeight + spacing)
            let w = CGFloat(slot.span) * cell + CGFloat(slot.span - 1) * spacing
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: w, height: rowHeight))
        }
    }
}
