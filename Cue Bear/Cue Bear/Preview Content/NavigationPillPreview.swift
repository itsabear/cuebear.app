//
//  NavigationPillPreview.swift
//  Cue Bear
//
//  Preview for Navigation Pill with Tutorial
//

import SwiftUI

#Preview("Nav Pill with Tutorial") {
    struct PreviewWrapper: View {
        @State private var controlAreaHeight: CGFloat = 200
        @State private var refreshID = UUID()

        var body: some View {
            ZStack {
                Color.gray.opacity(0.2)
                    .ignoresSafeArea()

                DraggableNavigationCapsule(
                    canPrev: true,
                    canNext: true,
                    onPrev: {},
                    onNext: {},
                    controlAreaHeight: $controlAreaHeight,
                    isEditing: false,
                    titleBarBottom: 100,
                    editCapsuleBottom: 150,
                    sizeMultiplier: 1.0,
                    isControlAreaCollapsed: false,
                    capsuleBounds: [:],
                    hasControlButtons: true,
                    themeColor: .blue
                )
                .id(refreshID)

                // Button to restart tutorial
                VStack {
                    HStack {
                        Spacer()
                        Button("Reset Tutorial") {
                            UserDefaults.standard.removeObject(forKey: "hasSeenNavPillTutorial")
                            refreshID = UUID()
                        }
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                    }
                    Spacer()
                }
            }
            .onAppear {
                // Force tutorial to show for preview
                UserDefaults.standard.removeObject(forKey: "hasSeenNavPillTutorial")
            }
        }
    }

    return PreviewWrapper()
}
