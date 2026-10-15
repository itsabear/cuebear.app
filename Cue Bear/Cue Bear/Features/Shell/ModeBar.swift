//
//  ModeBar.swift — Cue Bear Next
//
//  The bar at the top of every screen: menu, show / cue list, the Show | Build switch,
//  connection status, and Lock (Show) or Undo / Redo (Build).
//  While locked only the status and "Hold to unlock" remain, so nothing can leave the show by accident.
//

import SwiftUI
import UIKit

/// The two halves of the app.
enum CBScreenMode: String {
    case show   // perform: Now / Next / GO, setlist, controls
    case build  // set up: setlist, controls, library
}

struct ModeBar<TitlePopover: View>: View {
    let title: String
    @Binding var mode: CBScreenMode
    @Binding var isLocked: Bool
    @Binding var showTitlePopover: Bool
    @ObservedObject var coordinator: ConnectionCoordinator
    @ObservedObject var wifiClient: BridgeOutput
    @ObservedObject var rigs: BackupRigManager
    var canUndo: Bool
    var canRedo: Bool
    var onMenu: () -> Void
    var onConnections: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    @ViewBuilder var titlePopover: () -> TitlePopover

    @State private var unlockHint = false

    var body: some View {
        GeometryReader { geo in
            bar(compact: geo.size.width < 900)
        }
        .frame(height: 68)
        .background(CBColor.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CBColor.separator).frame(height: CBSize.hairline)
        }
    }

    /// `compact`: portrait, where the title and status get less room so the centered switch never overlaps them.
    private func bar(compact: Bool) -> some View {
        ZStack {
            // The switch sits in the middle of the bar whatever is on either side
            if !isLocked {
                modeSwitch
            }
            HStack(spacing: CBSpace.s) {
                if !isLocked {
                    CBSheetIconButton(systemName: "line.3.horizontal", weight: .medium, action: onMenu)
                        .accessibilityLabel("Menu")
                    titleButton(maxWidth: compact ? 190 : 260)
                } else {
                    Text(title)
                        .font(.cb(.body, .bold))
                        .foregroundStyle(CBColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: CBSpace.s)
                if mode == .build && !isLocked {
                    CBSheetIconButton(systemName: "arrow.uturn.backward", disabled: !canUndo, action: onUndo)
                        .accessibilityLabel("Undo")
                    CBSheetIconButton(systemName: "arrow.uturn.forward", disabled: !canRedo, action: onRedo)
                        .accessibilityLabel("Redo")
                }
                Button(action: onConnections) {
                    ShowStatusPill(coordinator: coordinator, wifiClient: wifiClient, rigs: rigs)
                }
                .buttonStyle(IOSPressButtonStyle())
                .disabled(isLocked)
                .frame(maxWidth: compact ? 160 : 260)
                .accessibilityHint("Opens Connections")
                if mode == .show {
                    lockButton
                }
            }
        }
        .padding(.horizontal, CBSpace.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pieces

    private func titleButton(maxWidth: CGFloat) -> some View {
        Button(action: { showTitlePopover.toggle() }) {
            HStack(spacing: CBSpace.s) {
                Text(title)
                    .font(.cb(.body, .bold))
                    .lineLimit(1)
                Image(systemName: showTitlePopover ? "chevron.up" : "chevron.down")
                    .font(.cbIcon(.caption))
                    .foregroundStyle(CBColor.textSecondary)
            }
            .foregroundStyle(CBColor.textPrimary)
            .padding(.horizontal, CBSpace.m)
            .frame(height: CBSize.control)
            .frame(maxWidth: maxWidth)
            .cbChip()
        }
        .buttonStyle(IOSPressButtonStyle())
        .popover(isPresented: $showTitlePopover, arrowEdge: .top) {
            titlePopover()
                .presentationCompactAdaptation(.popover)
                .presentationBackground(CBColor.background)
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            modeSegment("Show", .show)
            modeSegment("Build", .build)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: CBRadius.control).fill(CBColor.surface))
        .overlay(RoundedRectangle(cornerRadius: CBRadius.control).stroke(CBColor.stroke, lineWidth: CBSize.hairline))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode")
    }

    private func modeSegment(_ label: String, _ value: CBScreenMode) -> some View {
        let selected = mode == value
        return Button(action: {
            guard mode != value else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeInOut(duration: 0.2)) { mode = value }
        }) {
            Text(label)
                .font(.cb(.small, selected ? .bold : .regular))
                .foregroundStyle(selected ? CBColor.onPrimary : CBColor.textSecondary)
                .frame(width: 88, height: 36)
                .background(RoundedRectangle(cornerRadius: CBRadius.small).fill(selected ? CBColor.primary : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var lockButton: some View {
        if isLocked {
            HStack(spacing: CBSpace.s) {
                Image(systemName: "lock.fill").font(.cbIcon(.small))
                Text(unlockHint ? "Hold to unlock" : "Locked")
                    .font(.cb(.body, .semibold))
            }
            .foregroundStyle(CBColor.textPrimary)
            .padding(.horizontal, CBSpace.l)
            .frame(height: CBSize.control)
            .cbChip()
            .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
            .onTapGesture {
                withAnimation { unlockHint = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { unlockHint = false } }
            }
            .onLongPressGesture(minimumDuration: 1.0) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) { isLocked = false }
            }
            .accessibilityLabel("Locked")
            .accessibilityHint("Touch and hold for one second to unlock")
        } else {
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) { isLocked = true }
            }) {
                HStack(spacing: CBSpace.s) {
                    Image(systemName: "lock.open").font(.cbIcon(.small))
                    Text("Lock").font(.cb(.body, .semibold))
                }
                .foregroundStyle(CBColor.textPrimary)
                .padding(.horizontal, CBSpace.l)
                .frame(height: CBSize.control)
                .cbChip()
            }
            .buttonStyle(IOSPressButtonStyle())
            .accessibilityHint("Hides the menu and the Build switch until you unlock")
        }
    }
}
