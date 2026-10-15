//
//  ControlArea.swift — Cue Bear
//  (split out of ContentView.swift)
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

// MARK: - Control Area Scrollbar (iPhone)

struct ControlAreaScrollbar: View {
    let contentWidth: CGFloat
    let visibleWidth: CGFloat
    @Binding var scrollOffset: CGFloat

    private let trackInset: CGFloat = 20
    private let trackHeight: CGFloat = 6
    private let handleSize: CGFloat = 28

    var needsScrollbar: Bool {
        contentWidth > visibleWidth && visibleWidth > 0
    }

    private var trackWidth: CGFloat {
        max(0, visibleWidth - trackInset * 2)
    }

    private var maxScrollOffset: CGFloat {
        contentWidth - visibleWidth
    }

    private var scrollFraction: CGFloat {
        maxScrollOffset > 0 ? min(1, max(0, scrollOffset / maxScrollOffset)) : 0
    }

    private var handleCenterX: CGFloat {
        let halfHandle = handleSize / 2
        let usableTrack = trackWidth - handleSize
        return halfHandle + scrollFraction * usableTrack
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(width: trackWidth, height: trackHeight)

            // Round draggable handle
            Circle()
                .fill(Color.primary.opacity(0.3))
                .frame(width: handleSize, height: handleSize)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                .offset(x: handleCenterX - handleSize / 2)
        }
        .frame(height: handleSize)
        .padding(.horizontal, trackInset)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let trackUsable = trackWidth - handleSize
                    guard trackUsable > 0 else { return }
                    // Map drag X position to scroll fraction
                    let localX = value.location.x - handleSize / 2
                    let fraction = min(1, max(0, localX / trackUsable))
                    scrollOffset = fraction * maxScrollOffset
                }
        )
        .opacity(needsScrollbar ? 1 : 0)
        .allowsHitTesting(needsScrollbar)
    }
}

// MARK: - Reserved CCs for legacy transport mapping (kept for compatibility)
enum CBTransportCC { static let play = 100, stop = 101, prev = 102, next = 103 }

// MARK: - Grid Position Helper
struct GridPosition: Equatable {
    let col: Int
    let row: Int
}

// MARK: - Control Area

    // Widget-like packed grid layout types (visible to CBControlSection)
    struct GridSpan { let columns: Int; let rows: Int }
    struct GridSpanKey: LayoutValueKey { static let defaultValue = GridSpan(columns: 1, rows: 1) }
    struct GridOrigin { let col: Int; let row: Int; let isSet: Bool }
    struct GridOriginKey: LayoutValueKey { static let defaultValue = GridOrigin(col: -1, row: -1, isSet: false) }
    struct PackedGridLayout: Layout {
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat

        // FIX #6: Make Placement accessible for cache
        struct Placement { let originRow: Int; let originCol: Int; let span: GridSpan }

        // FIX #6: Implement cache structure to avoid recomputation
        struct LayoutCache {
            var width: CGFloat = 0
            var placements: [Placement] = []
            var rows: Int = 0
            var cellSize: CGSize = .zero
        }
        typealias Cache = LayoutCache

        // FIX #6: Implement makeCache to initialize cache
        func makeCache(subviews: Subviews) -> LayoutCache {
            return LayoutCache()
        }

        private func computePlacements(_ subviews: Subviews, width: CGFloat) -> (placements: [Placement], rows: Int, cellSize: CGSize) {
            let totalColSpacing = columnSpacing * CGFloat(max(0, columns - 1))
            let cellWidth = (width - totalColSpacing) / CGFloat(columns)
            let cellHeight = cellWidth
            var occupancy: [[Bool]] = Array(repeating: Array(repeating: false, count: columns), count: 1)

            func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
                if c + w > columns { return false }
                let rowsNeeded = r + h
                if rowsNeeded > occupancy.count {
                    occupancy.append(contentsOf: Array(repeating: Array(repeating: false, count: columns), count: rowsNeeded - occupancy.count))
                }
                for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
                return true
            }
            func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) {
                for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } }
            }

            var placements: [Placement] = []
            var placedIndex = Set<Int>()
            // First: honor explicit origins when possible
            for idx in subviews.indices {
                let span = subviews[idx][GridSpanKey.self]
                let origin = subviews[idx][GridOriginKey.self]
                if origin.isSet {
                    if origin.col >= 0, origin.row >= 0, fits(origin.row, origin.col, span.columns, span.rows) {
                        placements.append(Placement(originRow: origin.row, originCol: origin.col, span: span))
                        mark(origin.row, origin.col, span.columns, span.rows)
                        placedIndex.insert(idx)
                    }
                }
            }
            // Then: place remaining by first-fit
            for idx in subviews.indices where !placedIndex.contains(idx) {
                let span = subviews[idx][GridSpanKey.self]
                var placed = false
                var r = 0
                while !placed {
                    var c = 0
                    while c < columns {
                        if fits(r, c, span.columns, span.rows) { placements.append(Placement(originRow: r, originCol: c, span: span)); mark(r, c, span.columns, span.rows); placed = true; break }
                        c += 1
                    }
                    if !placed { r += 1 }
                }
            }

            var lastUsed = 0
            for (i, row) in occupancy.enumerated() { if row.contains(true) { lastUsed = i + 1 } }
            return (placements, max(1, lastUsed), CGSize(width: cellWidth, height: cellHeight))
        }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
            guard let width = proposal.width else { return .zero }
            // FIX #6: Use cached result if width hasn't changed
            if cache.width != width {
                let result = computePlacements(subviews, width: width)
                cache.width = width
                cache.placements = result.placements
                cache.rows = result.rows
                cache.cellSize = result.cellSize
            }
            let totalHeight = CGFloat(cache.rows) * cache.cellSize.height + rowSpacing * CGFloat(max(0, cache.rows - 1))
            return CGSize(width: width, height: totalHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
            let width = bounds.width
            // FIX #6: Use cached result if width hasn't changed
            if cache.width != width {
                let result = computePlacements(subviews, width: width)
                cache.width = width
                cache.placements = result.placements
                cache.rows = result.rows
                cache.cellSize = result.cellSize
            }
            for (idx, placement) in cache.placements.enumerated() {
                let x = CGFloat(placement.originCol) * (cache.cellSize.width + columnSpacing)
                let y = CGFloat(placement.originRow) * (cache.cellSize.height + rowSpacing)
                let w = CGFloat(placement.span.columns) * cache.cellSize.width + CGFloat(max(0, placement.span.columns - 1)) * columnSpacing
                let h = CGFloat(placement.span.rows) * cache.cellSize.height + CGFloat(max(0, placement.span.rows - 1)) * rowSpacing
                let rect = CGRect(x: bounds.minX + x, y: bounds.minY + y, width: w, height: h)
                subviews[idx].place(at: rect.origin, anchor: .topLeading, proposal: ProposedViewSize(rect.size))
            }
        }
    }
// Global cached portrait width to prevent repeated UIScreen access during SwiftUI layout
// This MUST be outside the struct to avoid recreation on each view instantiation
let globalCachedPortraitWidth: CGFloat = {
    let screenBounds = UIScreen.main.bounds
    return min(screenBounds.width, screenBounds.height)
}()

struct CBControlSection: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Binding var buttons: [ControlButton]
    @Binding var isEditing: Bool
    @Binding var perRow: Int
    @Binding var pendingAddIsFader: Bool?
    @Binding var reportedHeight: CGFloat
    @Binding var canAddMoreControls: Bool
    @Binding var isCollapsed: Bool  // Changed from @State to @Binding so ContentView can access it
    @Binding var selectedCue: UUID?  // Chosen cue to clear when entering edit mode
    @Binding var currentPage: Int  // Current page (0-3) for multi-page control area
    let conflictFor: [MIDIKey: String]
    @AppStorage("midiFiltersEnabled") var midiFiltersEnabled: Bool = true
    let midiFilter: Set<Int>
    let showMIDIData: Bool  // Toggle for showing MIDI data
    var onTap: (ControlButton) -> Void
    var onEditButton: (ControlButton) -> Void
    var onAddButton: () -> Void
    var onAddFader: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var canUndo: Bool = false
    var canRedo: Bool = false
    var onDelete: (ControlButton) -> Void
    var onMove: (IndexSet, Int) -> Void
    var onCancelTimer: () -> Void  // Called to cancel edit mode timer
    var onResetTimer: () -> Void  // Called to reset edit mode timer
    var usbServer: ConnectionManager
    var wifiClient: BridgeOutput
    var connectionCoordinator: ConnectionCoordinator
    let controlAreaColor: Color  // Theme control area color
    let buttonBackgroundColor: Color  // Theme button background color
    let lightButtonBackgroundColor: Color  // Slightly lighter version of title bar for button backgrounds
    let defaultCueColor: Color  // Theme default cue color for buttons/faders (includes custom accent)
    let standardButtonColor: Color  // Standard button color for UI controls (no custom accent)
    let textColor: Color  // Theme text color
    var markDirty: () -> Void
    var cueListEditMode: Bool = false  // When true, force collapse

    // Mac editor architecture adapted for iPad
    @State var dragging: ControlButton? = nil
    @State var previewLocation: GridPosition? = nil
    @State var dropSurfaceElevated: Bool = false
    @State   var editSessionNonce: Int = 0
    @State var isDragOperation: Bool = false
    @State var lastDropTime: Date = Date.distantPast
    @State var isAutoAssigning: Bool = false

    // Smooth drag system inspired by cue capsule success
    @State var dragTranslation: CGSize = .zero
    @State var dragStartLocation: CGPoint = .zero
    @State var shadowOffset: CGSize = .zero // For smooth shadow tracking

    // Track actual width for proper orientation handling
    // IMPORTANT: Initialize to 0, will be set by GeometryReader on first layout
    // Using UIScreen.main.bounds.width here causes freeze issues
    @State var actualWidth: CGFloat = 0

    // Track portrait width for consistent grid sizing in both orientations
    // Uses global cached value to prevent infinite layout loops
    var portraitWidth: CGFloat {
        return globalCachedPortraitWidth
    }

    // Track calculated height to avoid infinite render loops
    @State var cachedHeight: CGFloat = 0

    // iPhone horizontal scroll tracking for custom scrollbar
    @State var controlScrollOffset: CGFloat = 0
    @State var controlVisibleWidth: CGFloat = 0

    // Cross-page drag state
    @State var edgeDragTimer: Timer? = nil
    @State var edgeDragDirection: Int = 0  // -1 = left edge, +1 = right edge, 0 = not at edge
    let edgeDragDelay: TimeInterval = 0.5  // Delay before switching pages
    let edgeThreshold: CGFloat = 40  // Pixels from edge to trigger

    // PERFORMANCE FIX: Cache displacement calculations to prevent O(n²) recomputation during drag
    @State var displacementCache: [UUID: (col: Int, row: Int)] = [:]
    @State var displacementCacheKey: String = ""
    @State var hasInvalidDisplacement: Bool = false

    // iPhone 3-dot menu for adding controls
    @State var showControlAddMenu: Bool = false

    // Pixel snapping to prevent jitter (from cue capsule success)
    func snap(_ value: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        let scale = UIScreen.main.scale
        #else
        let scale: CGFloat = 2.0
        #endif
        return (value * scale).rounded() / scale
    }
    
    // Centralized drag state management
    func clearDragState(reason: String) {
        dragging = nil
        previewLocation = nil
        displacementCache.removeAll()
        displacementCacheKey = ""
        hasInvalidDisplacement = false
        dropSurfaceElevated = false
        isDragOperation = false
        dragTranslation = .zero
        dragStartLocation = .zero
        shadowOffset = .zero
        // Cancel any pending cross-page drag timer
        cancelEdgeDragTimer()
    }

    // Update displacement cache (called from onChange to avoid state modification during view update)
    func updateDisplacementCache() {
        guard let dragging = dragging, let preview = previewLocation else {
            // No active drag - clear cache
            displacementCache.removeAll()
            displacementCacheKey = ""
            hasInvalidDisplacement = false
            return
        }

        // Generate cache key for current drag state
        let cacheKey = "\(dragging.id)_\(preview.col)_\(preview.row)"

        // Only rebuild if cache key changed
        if displacementCacheKey != cacheKey {
            displacementCacheKey = cacheKey
            let result = computeAllDisplacements(draggedButton: dragging, targetPosition: preview, columns: columns)
            displacementCache = result.displacements
            hasInvalidDisplacement = result.hasInvalidDisplacement
        }
    }

    // Grid configuration (same as Mac editor)
    let columns = 8
    var columnSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 10 : 12
    }
    var rowSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 10 : 10
    }
    var gridPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 8 : 20
    }
    
    var canAddMoreControlsGlobal: Bool {
        // Check if there's space for either a button (2x1) or fader (1x2)
        let testButton = ControlButton(title: "Test", symbol: "square", kind: .cc, number: 0, channel: 1, isFader: false)
        let testFader = ControlButton(title: "Test", symbol: "square", kind: .cc, number: 0, channel: 1, isFader: true)

        // Return true if we can fit either a button OR a fader
        return findFirstAvailablePosition(for: testButton) != nil ||
               findFirstAvailablePosition(for: testFader) != nil
    }

    var canAddFader: Bool {
        // Check if there's space for EITHER a horizontal (2x1) OR vertical (1x2) fader
        // Horizontal fader
        let horizontalFader = ControlButton(
            title: "Test",
            symbol: "square",
            kind: .cc,
            number: 0,
            channel: 1,
            isFader: true,
            faderOrientation: "horizontal"
        )

        // Vertical fader
        let verticalFader = ControlButton(
            title: "Test",
            symbol: "square",
            kind: .cc,
            number: 0,
            channel: 1,
            isFader: true,
            faderOrientation: "vertical"
        )

        // Return true if we can fit EITHER orientation
        return findFirstAvailablePosition(for: horizontalFader) != nil ||
               findFirstAvailablePosition(for: verticalFader) != nil
    }

    // MARK: - Page Navigation

    let totalPages = 10  // Fixed number of pages (0-9)


    var body: some View {
        // Early return for collapsed/empty states - skip grid creation entirely
        if effectivelyCollapsed {
            return AnyView(collapsedView)
        }

        let gridArea = Group {
            // Only render the grid area when not collapsed
            if !effectivelyCollapsed {
                GeometryReader { outerProxy in
                    buildControlGrid(proxy: outerProxy, isCtrlEditing: isEditing, sessionNonce: editSessionNonce, usbServer: usbServer, wifiClient: wifiClient, connectionCoordinator: connectionCoordinator)
                    .onAppear {
                        // Update actual width when view appears
                        actualWidth = outerProxy.size.width
                    }
                    .onChange(of: outerProxy.size.width) { oldWidth, newWidth in
                        // Update actual width when orientation changes
                        // Guard against tiny changes that could cause layout loops
                        guard abs(newWidth - oldWidth) > 1 else { return }
                        actualWidth = newWidth
                    }
                }
                .id("ctrl-geo-\(isEditing)-sess-\(editSessionNonce)")
                // No maxWidth constraint - let the capsule width calculation determine the size
                // Use cachedHeight instead of calculateDynamicHeight() to prevent infinite layout loop
                .frame(height: cachedHeight > 0 ? cachedHeight : 200, alignment: .top)  // Align content to top
                .background(Color.clear)  // Ensure no white background
                // Skip drawingGroup on iPhone - can cause rendering issues with GeometryReader
                .modifier(ConditionalDrawingGroup(enabled: UIDevice.current.userInterfaceIdiom != .phone))
                .onAppear {
                    // Calculate initial height on appear
                    let height = calculateDynamicHeight()
                    cachedHeight = height
                    // Debounce reportedHeight update to avoid infinite loop
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if abs(reportedHeight - height) > 5 {
                            reportedHeight = height
                        }
                    }
                }
                .onChange(of: actualWidth) { _, _ in
                    // Recalculate height when width changes (orientation change)
                    let height = calculateDynamicHeight()
                    cachedHeight = height
                    // Debounce reportedHeight update to avoid infinite loop
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if abs(reportedHeight - height) > 5 {
                            reportedHeight = height
                        }
                    }
                }
            }
        }

        let styledGridArea = gridArea
            .opacity(effectivelyCollapsed ? 0 : 1)  // Hide grid completely when collapsed
            .onChange(of: isEditing) { _, newValue in
                if !newValue {
                    // fully reset drag/drop when leaving edit
                    clearDragState(reason: "onChange - leaving edit mode")
                }
            }
            .onChange(of: cueListEditMode) { _, newValue in
                // Collapse control area when cue list enters edit mode
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    if newValue {
                        isCollapsed = true
                    } else {
                        isCollapsed = false
                        // Auto-enter edit mode when expanding empty control area
                        if buttons.isEmpty {
                            isEditing = true
                        }
                    }
                }
            }
            .onChange(of: buttons.count) { _, _ in
                let height = calculateDynamicHeight()
                cachedHeight = height
                // Debounce reportedHeight update to avoid infinite loop
                // The delay breaks the synchronous layout cycle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
            .onChange(of: buttons.map { "\($0.gridRow ?? -1)" }.joined()) { _, _ in
                // Recalculate when button positions change (not just count)
                let height = calculateDynamicHeight()
                cachedHeight = height
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
            .onChange(of: isCollapsed) { _, _ in
                let height = calculateDynamicHeight()
                cachedHeight = height
                // Debounce reportedHeight update to avoid infinite loop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
            .onChange(of: isEditing) { _, _ in
                // Recalculate when entering/exiting edit mode (edit mode shows full 4 rows)
                let height = calculateDynamicHeight()
                cachedHeight = height
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if abs(reportedHeight - height) > 5 {
                        reportedHeight = height
                    }
                }
            }
        
        let gridWithLifecycle = styledGridArea
                .onAppear {
                // Auto-assign positions on first load - call immediately since onAppear is safe
                    autoAssignGridPositions()
                }
            .onChange(of: buttons.count) { _, newCount in
                debugPrint("🔄 buttons.count changed to \(newCount) - dragging: \(dragging?.title ?? "none"), isDragOperation: \(isDragOperation)")

                // Auto-unfold and enter edit mode when control area becomes empty
                if newCount == 0 && isCollapsed {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isCollapsed = false
                        isEditing = true  // Always edit mode when empty
                    }
                }

                // Only auto-assign when buttons are actually added/removed, not during drag operations
                // Also avoid auto-assign shortly after a drop to prevent position interference
                let timeSinceLastDrop = Date().timeIntervalSince(lastDropTime)
                if dragging == nil && !isDragOperation && timeSinceLastDrop > 0.5 && !isAutoAssigning {
                    // Auto-assign positions when buttons are added/removed (deferred to avoid state modification warnings)
                    DispatchQueue.main.async {
                        debugPrint("🔧 Auto-assigning positions due to button count change (new count: \(newCount))")
                        self.isAutoAssigning = true
                        autoAssignGridPositions()
                        self.isAutoAssigning = false
                    }
                } else {
                    let reason = dragging != nil ? "dragging in progress" :
                                isDragOperation ? "drag operation flag set" :
                                isAutoAssigning ? "auto-assign already in progress" :
                                "recent drop (time since: \(String(format: "%.2f", timeSinceLastDrop))s)"
                    debugPrint("⏭️ Skipping auto-assign: \(reason)")
                }
            }
            .onChange(of: dragging) { _, newValue in
                    debugPrint("🔄 dragging state changed → \(newValue?.title ?? "nil")")

                    if newValue != nil {
                        // Dragging started - cancel timer to keep edit mode active
                        onCancelTimer()
                    } else {
                        // Dragging ended - reset timer
                        onResetTimer()
                    }

                    // If dragging ended without going through performDrop, clean up state
                    if newValue == nil {
                        isDragOperation = false
                        // Use a small delay to allow performDrop to complete first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if dragging == nil && previewLocation != nil {
                                debugPrint("🧹 Fallback cleanup - clearing lingering preview")
                                previewLocation = nil
                                dropSurfaceElevated = false
                            }
                        }
                    }
                }
                .onChange(of: previewLocation) { _, newValue in
                    debugPrint("🔄 Preview location changed: \(newValue?.col ?? -1),\(newValue?.row ?? -1)")
                }
                .onChange(of: dragging?.id) { _, _ in
                    // Update displacement cache when drag state changes
                    updateDisplacementCache()
                }
                .onChange(of: previewLocation) { _, _ in
                    // Update displacement cache when preview location changes
                    updateDisplacementCache()
                }

        // Expanded view - only reached when not collapsed
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let isLandscape = verticalSizeClass == .compact

        // Calculate grid width (fixed, based on screen size only)
        let gridWidthWithPadding: CGFloat? = {
            // iPhone: Only apply in landscape, use full width in portrait
            if isPhone && !isLandscape {
                return nil
            }

            // iPad landscape: Calculate width based on full columns
            if !isPhone && isLandscape {
                // Use same cell size calculation as portrait for consistency
                let totalSpacing = CGFloat(columns - 1) * columnSpacing
                let actualHorizontalPadding = 16 + columnSpacing
                let availableWidth = portraitWidth - (2 * actualHorizontalPadding) - totalSpacing
                var cellSize = floor(availableWidth / CGFloat(columns))

                // Apply same height constraint logic - use cached value to avoid freeze
                let landscapeHeight = globalCachedPortraitWidth
                let maxHeight = isPhone ? landscapeHeight * 0.8 : landscapeHeight * 0.7
                let actualVerticalPadding: CGFloat = 18 + (isPhone ? 0 : 8)  // top + bottom
                let extraPadding: CGFloat = 0
                let availableGridHeight = maxHeight - actualVerticalPadding - extraPadding
                // Always use 4 rows for consistent sizing regardless of edit mode
                let displayRows = 4
                let verticalGaps = max(0, displayRows - 1)
                let maxCellSize = (availableGridHeight - CGFloat(verticalGaps) * rowSpacing) / CGFloat(displayRows)
                cellSize = min(cellSize, floor(maxCellSize))

                // Use full columns for fixed width
                let gridWidth = CGFloat(columns) * cellSize + CGFloat(max(0, columns - 1)) * columnSpacing
                // Capsule padding: 16pt left + 16pt right (added at line 7381)
                let capsulePadding: CGFloat = 32
                let finalWidth = gridWidth + (columnSpacing * 2) + capsulePadding
                return finalWidth
            }

            // iPhone landscape: Also use full width
            let totalSpacing = CGFloat(columns - 1) * columnSpacing
            let actualHorizontalPadding = 16 + columnSpacing
            let availableWidth = portraitWidth - (2 * actualHorizontalPadding) - totalSpacing
            var cellSize = floor(availableWidth / CGFloat(columns))

            // Apply height constraint - use 80% of landscape height (cached to avoid freeze)
            let landscapeHeight = globalCachedPortraitWidth
            let maxHeight = landscapeHeight * 0.8
            let actualVerticalPadding: CGFloat = 18
            let availableGridHeight = maxHeight - actualVerticalPadding
            let displayRows = 4
            let verticalGaps = max(0, displayRows - 1)
            let maxCellSize = (availableGridHeight - CGFloat(verticalGaps) * rowSpacing) / CGFloat(displayRows)
            cellSize = min(cellSize, floor(maxCellSize))

            // Use full columns for fixed width
            let gridWidth = CGFloat(columns) * cellSize + CGFloat(max(0, columns - 1)) * columnSpacing
            let capsulePadding: CGFloat = 32
            let finalWidth = gridWidth + (columnSpacing * 2) + capsulePadding
            return finalWidth
        }()

        let baseView = Group {
            VStack(spacing: 0) {
                headerView
                    .zIndex(0)  // Header stays behind
                gridWithLifecycle
                    .zIndex(1)  // Grid (with X buttons) renders on top
            }
            .background(
                RoundedRectangle(cornerRadius: CBRadius.panel)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: CBRadius.panel)
                            .stroke(CBColor.stroke, lineWidth: CBSize.hairline)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
            )
        }

        let shapedView = baseView
        .padding(.horizontal, 16)  // Add padding to keep capsule content from edges
        .padding(.bottom, isPhone ? 0 : 8)
        // NOTE: Deliberately NOT reporting CapsuleBoundsPreferenceKey here
        // Reporting bounds causes an infinite loop:
        // 1. CBControlSection reports bounds via preference
        // 2. ContentView receives preference and updates capsuleBounds state
        // 3. ContentView re-renders
        // 4. controlSectionView computed property creates NEW CBControlSection with NEW closures
        // 5. SwiftUI sees new closures as "different" view and recreates CBControlSection
        // 6. Go to step 1 -> infinite loop / freeze
        //
        // Tutorial 4 removed (two-finger scroll no longer exists)

        let controlCapsule = shapedView
        .compositingGroup()
        .onChange(of: isEditing) { _, editing in
            clearDragState(reason: "edit mode toggle")
        }
        .onAppear {
            canAddMoreControls = canAddMoreControlsGlobal
        }
        .onChange(of: buttons.count) { _, _ in
            canAddMoreControls = canAddMoreControlsGlobal
        }

        // Apply width constraint (iPad: both orientations, iPhone: landscape only)
        if let width = gridWidthWithPadding {
            // Use fixed width in both orientations to allow outer frame alignment to work
            return AnyView(
                controlCapsule
                    .frame(width: width)  // Fixed width allows outer frame's .bottomTrailing to align correctly
            )
        } else {
            return AnyView(controlCapsule)
        }
    }
    
// MARK: - Performance List moved to ControlSubviews.swift

// MARK: - Performance Row moved to ControlSubviews.swift

// MARK: - Editor: Setlist column
// MARK: - CBSetlistColumn moved to ControlSubviews.swift

// MARK: - Editor: Library column
// MARK: - CBLibraryColumn moved to ControlSubviews.swift

// MARK: - CBRowLikeLibrary moved to ControlSubviews.swift

// MARK: - Full-width batch toolbar
// MARK: - CBBatchToolbar moved to ControlSubviews.swift

// MARK: - Connections Sheet (unchanged)
// MARK: - CBConnectionsSheet moved to ControlSubviews.swift

    struct CBGridDropSurface: View {
        let width: CGFloat
        let height: CGFloat
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        @Binding var buttons: [ControlButton]
        @Binding var dragging: ControlButton?
        @Binding var previewLocation: GridPosition?
        let isActive: Bool
        
        var body: some View {
                        Rectangle()
                .fill(Color.clear)
                .frame(width: width, height: height)
                // .onDrop(of: [UTType.text], delegate: CBGridDropSurfaceDelegate( // Disabled for iOS-style drag
                //     columns: columns,
                //     columnSpacing: columnSpacing,
                //     rowSpacing: rowSpacing,
                //     cellSize: cellSize,
                //     buttons: $buttons,
                //     dragging: $dragging,
                //     previewLocation: $previewLocation,
                //     isActive: isActive
                // ))
                .allowsHitTesting(isActive)
        }
    }
    
    struct CBDragPreview: View {
        let dragItem: ControlButton
        let previewLocation: (col: Int, row: Int)
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        
        var body: some View {
            let width = CGFloat(dragItem.gridWidth) * cellSize + CGFloat(dragItem.gridWidth - 1) * columnSpacing
            let height = CGFloat(dragItem.gridHeight) * cellSize + CGFloat(dragItem.gridHeight - 1) * rowSpacing
            let x = CGFloat(previewLocation.col) * (cellSize + columnSpacing)
            let y = CGFloat(previewLocation.row) * (cellSize + rowSpacing)
            
            RoundedRectangle(cornerRadius: CBRadius.card)
                .fill(Color.accentColor.opacity(0.3))
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: width, height: height)
                .position(x: x + width/2, y: y + height/2)
                .allowsHitTesting(false)
        }
    }
    

    struct CBGridDropSurfaceDelegate: DropDelegate {
        let columns: Int
        let columnSpacing: CGFloat
        let rowSpacing: CGFloat
        let cellSize: CGFloat
        @Binding var buttons: [ControlButton]
        @Binding var dragging: ControlButton?
        @Binding var previewLocation: GridPosition?
        let isActive: Bool
        
        func validateDrop(info: DropInfo) -> Bool {
            // Always return true to prevent 🚫 icon
            return true
        }
        
        func dropEntered(info: DropInfo) {
            guard isActive, dragging != nil else { 
                debugPrint("🔴 dropEntered: not active or no dragging")
                return 
            }
            updatePreview(info: info)
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            // Continuously update preview as pointer moves
            updatePreview(info: info)
            return DropProposal(operation: .move)
        }
        
        func dropExited(info: DropInfo) {
            previewLocation = nil
        }
        
        func updatePreview(info: DropInfo) {
            guard let dragging = dragging else { return }
            let p = info.location
            let col = max(0, Int((p.x / (cellSize + columnSpacing)).rounded(.down)))
            let row = max(0, Int((p.y / (cellSize + rowSpacing)).rounded(.down)))
            let targetWidth = dragging.gridWidth
            let fits = col + targetWidth <= columns
            previewLocation = fits ? GridPosition(col: col, row: row) : nil
        }
        
        func performDrop(info: DropInfo) -> Bool {
            guard isActive, let dragging = dragging else { 
                debugPrint("🔴 performDrop failed: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
                return false 
            }
            
            // Calculate drop position from pointer location
            let p = info.location
            let col = max(0, Int((p.x / (cellSize + columnSpacing)).rounded(.down)))
            let row = max(0, Int((p.y / (cellSize + rowSpacing)).rounded(.down)))
            
            debugPrint("✅ performDrop to (\(col),\(row)) for \(dragging.title) - using smart placement")
            
            // Use smart placement to handle overlaps
            let success = smartPlacement(
                item: dragging,
                targetCol: col,
                targetRow: row,
                items: &buttons
            )
            
            if success {
                debugPrint("✅ Smart placement successful for \(dragging.title)")
            } else {
                debugPrint("🔴 Smart placement failed for \(dragging.title)")
            }
            
            // Clear preview and dragging state immediately
            previewLocation = nil
            self.dragging = nil
            
            return success
        }
        
        // Smart placement logic with repositioning
        func smartPlacement(
            item: ControlButton,
            targetCol: Int,
            targetRow: Int,
            items: inout [ControlButton]
        ) -> Bool {
            let itemWidth = item.gridWidth
            let itemHeight = item.gridHeight
            if !hasOverlap(col: targetCol, row: targetRow, width: itemWidth, height: itemHeight, items: items, excluding: item.id) {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].gridCol = targetCol
                    items[index].gridRow = targetRow
            return true
        }
                return false
            }
            let overlapping = findOverlappingItems(
                col: targetCol, row: targetRow, width: itemWidth, height: itemHeight, 
                items: items, excluding: item.id
            )
            var repositionPlan: [(ControlButton, Int, Int)] = []
            for overlappingItem in overlapping {
                let newPos = findFreePosition(for: overlappingItem, items: items, excluding: [item.id] + overlapping.map { $0.id })
                if let (newCol, newRow) = newPos {
                    repositionPlan.append((overlappingItem, newCol, newRow))
                } else {
                    return false
                }
            }
            for (itemToMove, newCol, newRow) in repositionPlan {
                if let index = items.firstIndex(where: { $0.id == itemToMove.id }) {
                    items[index].gridCol = newCol
                    items[index].gridRow = newRow
                }
            }
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].gridCol = targetCol
                items[index].gridRow = targetRow
                return true
            }
            return false
        }
        
        // Check for overlaps
        func hasOverlap(col: Int, row: Int, width: Int, height: Int, items: [ControlButton], excluding excludeId: UUID) -> Bool {
            for item in items {
                guard item.id != excludeId,
                      let itemCol = item.gridCol,
                      let itemRow = item.gridRow else { continue }

                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight
                
                if rectsOverlap(
                    r1: (col, row, width, height),
                    r2: (itemCol, itemRow, itemWidth, itemHeight)
                ) {
                    return true
                }
            }
            return false
        }
        
        // Find overlapping items
        func findOverlappingItems(col: Int, row: Int, width: Int, height: Int, items: [ControlButton], excluding excludeId: UUID) -> [ControlButton] {
            var overlapping: [ControlButton] = []
            
            for item in items {
                guard item.id != excludeId,
                      let itemCol = item.gridCol,
                      let itemRow = item.gridRow else { continue }

                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight
                
                if rectsOverlap(
                    r1: (col, row, width, height),
                    r2: (itemCol, itemRow, itemWidth, itemHeight)
                ) {
                    overlapping.append(item)
                }
            }
            return overlapping
        }
        
        // Find free position for an item
        func findFreePosition(for item: ControlButton, items: [ControlButton], excluding excludeIds: [UUID]) -> (Int, Int)? {
            let itemWidth = item.gridWidth
            let itemHeight = item.gridHeight
            let maxCols = 8
            let maxRows = 4
            
            // Try positions in order of preference
            for row in 0..<maxRows {
                for col in 0..<maxCols {
                    if col + itemWidth <= maxCols && row + itemHeight <= maxRows {
                        var hasConflict = false
                        for otherItem in items {
                            guard !excludeIds.contains(otherItem.id),
                                  let otherCol = otherItem.gridCol,
                                  let otherRow = otherItem.gridRow else { continue }
                            
                            let otherWidth = otherItem.gridWidth
                            let otherHeight = otherItem.gridHeight
                            
                            if rectsOverlap(
                                r1: (col, row, itemWidth, itemHeight),
                                r2: (otherCol, otherRow, otherWidth, otherHeight)
                            ) {
                                hasConflict = true
                                break
                            }
                        }
                        if !hasConflict {
                            return (col, row)
                        }
                    }
                }
            }
            return nil
        }
        
        // Rectangle overlap check
        func rectsOverlap(r1: (Int, Int, Int, Int), r2: (Int, Int, Int, Int)) -> Bool {
            let (x1, y1, w1, h1) = r1

            let (x2, y2, w2, h2) = r2
            return !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1)
        }
    }
}

// MARK: - Helper struct for collision detection
struct GridRect {
    let col: Int
    let row: Int
    let width: Int
    let height: Int
}

// MARK: - Conditional Drag Modifier
struct ConditionalDragModifier: ViewModifier {
    let isEditing: Bool
    let onDrag: () -> NSItemProvider
    let buttonTitle: String

    func body(content: Content) -> some View {
        if isEditing {
            content.onDrag {
                debugPrint("🟢 ConditionalDragModifier: onDrag triggered for: \(buttonTitle)")
                let provider = onDrag()
                debugPrint("🟢 ConditionalDragModifier: NSItemProvider created")
                return provider
            }
        } else {
            content
        }
    }
}

// MARK: - Simple seeded RNG for per-tile wobble variety
struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        // Mix the signed seed into a 64-bit state
        let mixed = UInt64(bitPattern: Int64(seed)) ^ 0x9E3779B97F4A7C15
        state = mixed != 0 ? mixed : 0xA4093822299F31D0 // avoid zero state
    }

    // xorshift64*
    private mutating func nextRaw() -> UInt64 {
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }

    mutating func nextNormalized() -> Double {
        let v = nextRaw()
        return Double(v) / Double(UInt64.max)
    }
}

// MARK: - Press effect gesture only when not editing (prevents conflicts with system drag)
// Also skips on iPhone to allow ScrollView horizontal scrolling
struct PressEffectWhenNotEditing: ViewModifier {
    let isEditing: Bool
    let onChange: () -> Void
    let onEnd: () -> Void

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    func body(content: Content) -> some View {
        // Skip on iPhone to allow ScrollView scrolling, skip when editing for system drag
        if isEditing || isPhone {
            content
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onChange() }
                    .onEnded { _ in onEnd() }
            )
        }
    }
}

// MARK: - iPad Control Tile (adapted from Mac editor)
struct iPadControlTile: View {
    let button: ControlButton
    let takenBy: String?
    let isEditing: Bool
    let isDragging: Bool
    let defaultCueColor: Color  // Theme default cue color
    let showMIDIData: Bool  // Toggle for showing MIDI data
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onDrag: () -> NSItemProvider
    var onFaderMIDI: (Int, Int, Int, String, UUID) -> Void
    
    @State private var isPressed = false
    @State private var isTouching = false // Track touch state for instant feedback
    @State private var faderValue: Double = 0.66 // 0.0 to 1.0
    @State private var faderVisualValue: Double = 0.66
    @State private var lastSentValue: Double = 0.0 // Track last MIDI value sent
    // FIX #7: Replace Date() timing with frame counter for better performance
    @State private var frameCounter: Int = 0
    @State private var firedThisPress: Bool = false
    // FIX #1: Track notification subscription to prevent memory leak
    @State private var faderUpdateCancellable: AnyCancellable? = nil

    // Wobble state - now uses shared animator
    @ObservedObject private var wobbleAnimator = WobbleAnimator.shared
    @State private var wobbleID = UUID()

    // Theme access
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedThemeID") private var selectedThemeID: String = "default"

    private var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // iPhone/compact mode detection
    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    // MARK: - iPhone-style wobble implementation (using shared animator)
    private func startWobble() {
        guard isEditing else { return }

        var rng = SeededRandom(seed: button.id.uuidString.hashValue)
        let amplitude = 0.8 + Double(rng.nextNormalized()) * 0.4
        let scaleDelta = 0.002 + Double(rng.nextNormalized()) * 0.001
        wobbleAnimator.startWobbling(for: wobbleID, amplitude: amplitude, scaleDelta: scaleDelta)
    }

    private func stopWobble() {
        wobbleAnimator.stopWobbling(for: wobbleID)
    }
    
    var body: some View {
        ZStack {
            if button.isFader == true {
                if isEditing {
                    // v1.0.8: In edit mode, wrap with tap gesture to open edit sheet
                    ZStack {
                        FaderTileContent()
                            .contentShape(Rectangle())
                    }
                    .onTapGesture { onEdit() }
                } else {
                    // In play mode, render normally with drag gestures
                    FaderTileContent()
                }
            } else {
                if isEditing {
                    // In edit mode, render as plain content to prioritize drag
                    ZStack {
                ButtonTileContent()
                            .contentShape(Rectangle())
                    }
                    .onTapGesture { onEdit() }
                } else {
                    // Fire MIDI on touch down (not touch up) for zero-latency feel
                    ButtonTileContent()
                        .contentShape(Rectangle())
                        .modifier(PressGestureModifier(isPhone: isPhone, isTouching: $isTouching, isPressed: $isPressed, onTouchDown: onTap))
                }
            }
            
            // Delete button in edit mode — positioned so circle center sits at tile corner
            if isEditing {
                Button(action: onDelete) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.9))
                            .frame(width: isPhone ? 20 : 30, height: isPhone ? 20 : 30)
                        Image(systemName: "xmark")
                            .font(.cbIcon(points: isPhone ? 10 : 13, .bold))
                            .foregroundColor(Color(uiColor: .systemBackground))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle().scale(2))  // Generous hit area around the circle
                .position(x: isPhone ? 4 : 0, y: isPhone ? 4 : 0)  // Slightly inset from corner
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(isEditing ? Rectangle() : Rectangle())
        .background(isEditing ? Color.clear : Color.primary.opacity(0.001))
            .opacity(isDragging ? (button.isFader == true ? 0.8 : 0.5) : 1.0)
            // .modifier(ConditionalDragModifier(isEditing: isEditing, onDrag: onDrag, buttonTitle: button.title)) // Disabled in favor of smooth drag
            .allowsHitTesting(isEditing ? true : true)
        .modifier(ConditionalWobbleModifier(isPhone: isPhone, wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
        .onChange(of: isEditing) { _, editing in
            if !isPhone {
                // Only wobble on iPad
                if editing { startWobble() } else { stopWobble() }
            }
        }
        .onAppear {
            // Initialize fader value from stored value in ControlButton model
            if let storedValue = button.faderValue {
                faderValue = storedValue
                faderVisualValue = storedValue
            } else {
                // Use default value for new faders
                let defaultValue = 0.66
                faderValue = defaultValue
                faderVisualValue = defaultValue
            }
            // Only start wobble on iPad (iPhone never wobbles)
            if isEditing && !isPhone { startWobble() }

            // FIX #1: Setup notification subscription using Combine to prevent memory leak
            faderUpdateCancellable = NotificationCenter.default.publisher(for: Notification.Name("cbUpdateFaderFromDAW"))
                .sink { [self] notif in
                    guard let info = notif.userInfo as? [String: Any],
                          let buttonID = info["buttonID"] as? String,
                          let value = info["value"] as? Double,
                          buttonID == button.id.uuidString else {
                        return
                    }

                    // Update fader values from DAW MIDI input
                    faderValue = value
                    faderVisualValue = value
                }
        }
        .onDisappear {
            stopWobble()
            // FIX #1: Clean up notification subscription to prevent memory leak
            faderUpdateCancellable?.cancel()
            faderUpdateCancellable = nil
        }
    }
    
    // Get custom button color or default to theme's defaultCueColor
    private var customButtonColor: Color {
        if let hex = button.colorHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return defaultCueColor
    }

    // Filled tile background — always accent color (palette style)
    private var buttonBackgroundColor: Color {
        if button.isToggle == true {
            // Toggle buttons: clear visual distinction between ON and OFF
            let isOn = button.toggleState || isPressed
            return isOn ? customButtonColor : customButtonColor.opacity(0.45)
        } else {
            // Momentary buttons: subtle press feedback
            return isPressed ? customButtonColor : customButtonColor.opacity(0.9)
        }
    }

    // Adaptive text color based on tile background brightness (palette style)
    private var buttonTextColor: Color {
        customButtonColor.needsDarkText() ? .black : .white
    }

    // Icon color matches text color (palette style)
    private var buttonIconColor: Color {
        buttonTextColor
    }

    @ViewBuilder
    private func ButtonTileContent() -> some View {
        VStack(spacing: isPhone ? 1 : 4) {
            Spacer(minLength: 0)

            if button.symbol.isEmpty {
                // Text only
                Text(button.title)
                    .font(.cb(points: isPhone ? 11 : 12, .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else if button.title.isEmpty {
                // Icon only
                Image(systemName: button.symbol)
                    .font(.cbIcon(points: isPhone ? 16 : 22, .semibold))
                    .foregroundColor(buttonIconColor)
            } else {
                // Icon + text
                Image(systemName: button.symbol)
                    .font(.cbIcon(points: isPhone ? 14 : 22, .semibold))
                    .foregroundColor(buttonIconColor)
                Text(button.title)
                    .font(.cb(points: isPhone ? 10 : 12, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if showMIDIData {
                Text(midiLabel())
                    .font(.cb(points: isPhone ? 8 : 9))
                    .foregroundColor(buttonTextColor.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .foregroundColor(buttonTextColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CBRadius.small)
                .fill(buttonBackgroundColor)
        )
        .opacity(isTouching ? 0.7 : 1.0)
        .transaction { t in
            // Instant dim on press, animated restore on release
            if isTouching { t.animation = nil } else { t.animation = .easeOut(duration: 0.1) }
        }
        .animation(.easeOut(duration: 0.08), value: button.toggleState)
    }

    @ViewBuilder
    private func FaderTileContent() -> some View {
        GeometryReader { geo in
            let isHorizontal = (button.faderOrientation == "horizontal")
            let direction = button.faderDirection ?? (isHorizontal ? "right" : "up")

            if isHorizontal {
                // HORIZONTAL FADER
                let headWidth: CGFloat = 20
                let w = max(0, geo.size.width - headWidth)
                // shouldReverse is only used for input mapping in gesture, not for visual rendering
                let shouldReverse = (direction == "left")
                // Fill alignment: "right" fills from left, "left" fills from right
                // The alignment handles the directional flip, so we use the same value for both
                let fillAlignment: Alignment = (direction == "right") ? .leading : .trailing

                ZStack(alignment: fillAlignment) {
                    // Main fader track background - filled style with 8pt corners
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .fill(customButtonColor.opacity(0.2))

                    // Fader fill (dynamic based on faderValue) - alignment handles the direction
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .fill(customButtonColor.opacity(0.85))
                        .frame(width: w * faderVisualValue)
                        .padding(3)

                    // Fader head (dynamic position) - conditional offset for direction
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .fill(customButtonColor)
                        .frame(width: headWidth)
                        .offset(x: (direction == "right") ? (w * faderVisualValue) : -(w * faderVisualValue))
                        .padding(.vertical, 6)
                }
                .gesture(
                    // Apply drag gesture directly to the fader track area
                    isEditing ? nil : DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Instant touch feedback on first touch
                            if !isTouching {
                                isTouching = true
                            }

                            let dragX = value.location.x
                            let faderTrackWidth = w

                            // Convert X position to fader value (0.0 to 1.0)
                            let normalizedX = max(0, min(faderTrackWidth, dragX - headWidth/2))
                            var targetValue = max(0.0, min(1.0, Double(normalizedX) / Double(faderTrackWidth)))

                            // Reverse if direction is "left"
                            if shouldReverse {
                                targetValue = 1.0 - targetValue
                            }

                            // Update both values immediately for maximum responsiveness
                            faderValue = targetValue
                            faderVisualValue = targetValue

                            // FIX #7: Use frame counter instead of Date() for throttling
                            frameCounter += 1
                            let valueChange = abs(targetValue - lastSentValue)

                            // Send MIDI every 2nd frame or if value changed significantly
                            // 1. Every 2nd frame (avoids Date() overhead)
                            // 2. Value changed significantly (>0.01 = ~1.3 MIDI steps)
                            // 3. At extreme values (0.0 or 1.0)
                            if frameCounter % 2 == 0 || valueChange > 0.01 || targetValue == 0.0 || targetValue == 1.0 {
                                let midiValue = Int(round(targetValue * 127))
                                lastSentValue = targetValue
                                onFaderMIDI(button.channel, button.number, midiValue, button.title, button.id)
                            }
                        }
                        .onEnded { _ in
                            // End touch feedback
                            isTouching = false

                            // Ensure final MIDI value is sent
                            let finalMidiValue = Int(round(faderValue * 127))
                            onFaderMIDI(button.channel, button.number, finalMidiValue, button.title, button.id)
                            lastSentValue = faderValue
                            // FIX #7: Reset frame counter
                            frameCounter = 0
                        }
                )

                // Title overlay - centered
                // Text color adapts to whether the fader fill is behind the text
                // For horizontal: text is centered, so it's covered when fill > ~50%
                HStack {
                    let filledTextColor: Color = customButtonColor.needsDarkText() ? .black : .white
                    let emptyTextColor: Color = .white  // Dark mode background
                    let textOnFill = faderVisualValue > 0.45
                    let faderTextColor = textOnFill ? filledTextColor : emptyTextColor
                    Text(button.title)
                        .font(.cb(.caption, .bold))
                        .foregroundColor(faderTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.leading, isPhone ? 2 : 4)
                    Spacer()
                    if showMIDIData {
                        Text(midiLabel())
                            .font(.cb(.micro))
                            .foregroundColor(faderTextColor.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.trailing, isPhone ? 2 : 4)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false) // Don't interfere with fader drag
            } else {
                // VERTICAL FADER
                let headHeight: CGFloat = 20
                let h = max(0, geo.size.height - headHeight)
                // shouldReverse is only used for input mapping in gesture, not for visual rendering
                let shouldReverse = (direction == "down")
                // Fill alignment: "up" fills from bottom, "down" fills from top
                // The alignment handles the directional flip, so we use the same value for both
                let fillAlignment: Alignment = (direction == "up") ? .bottom : .top

                ZStack(alignment: fillAlignment) {
                    // Main fader track background - filled style with 8pt corners
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .fill(customButtonColor.opacity(0.2))

                    // Fader fill (dynamic based on faderValue) - alignment handles the direction
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .fill(customButtonColor.opacity(0.85))
                        .frame(height: h * faderVisualValue)
                        .padding(3)

                    // Fader head (dynamic position) - conditional offset for direction
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .fill(customButtonColor)
                        .frame(height: headHeight)
                            .offset(y: (direction == "up") ? -(h * faderVisualValue) : (h * faderVisualValue))
                        .padding(.horizontal, 6)
                }
                .gesture(
                    // Apply drag gesture directly to the fader track area
                    isEditing ? nil : DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Instant touch feedback on first touch
                            if !isTouching {
                                isTouching = true
                            }

                            let dragY = value.location.y
                            let faderTrackHeight = h

                            // Convert Y position to fader value (0.0 to 1.0)
                            let normalizedY = max(0, min(faderTrackHeight, dragY - headHeight/2))
                            var targetValue = max(0.0, min(1.0, 1.0 - (Double(normalizedY) / Double(faderTrackHeight))))

                            // Reverse if direction is "down"
                            if shouldReverse {
                                targetValue = 1.0 - targetValue
                            }

                            // Update both values immediately for maximum responsiveness
                            faderValue = targetValue
                            faderVisualValue = targetValue

                            // FIX #7: Use frame counter instead of Date() for throttling
                            frameCounter += 1
                            let valueChange = abs(targetValue - lastSentValue)

                            // Send MIDI every 2nd frame or if value changed significantly
                            // 1. Every 2nd frame (avoids Date() overhead)
                            // 2. Value changed significantly (>0.01 = ~1.3 MIDI steps)
                            // 3. At extreme values (0.0 or 1.0)
                            if frameCounter % 2 == 0 || valueChange > 0.01 || targetValue == 0.0 || targetValue == 1.0 {
                                let midiValue = Int(round(targetValue * 127))
                                lastSentValue = targetValue
                                onFaderMIDI(button.channel, button.number, midiValue, button.title, button.id)
                            }
                        }
                        .onEnded { _ in
                            // End touch feedback
                            isTouching = false

                            // Ensure final MIDI value is sent
                            let finalMidiValue = Int(round(faderValue * 127))
                            onFaderMIDI(button.channel, button.number, finalMidiValue, button.title, button.id)
                            lastSentValue = faderValue
                            // FIX #7: Reset frame counter
                            frameCounter = 0
                        }
                )

                // Title overlay - centered
                // Text color adapts to whether the fader fill is behind the text
                // For vertical "up": title at top needs high fill, MIDI at bottom covered first
                // For vertical "down": title at top covered first, MIDI at bottom needs high fill
                VStack(spacing: 2) {
                    let filledTextColor: Color = customButtonColor.needsDarkText() ? .black : .white
                    let emptyTextColor: Color = .white  // Dark mode background
                    let titleOnFill = (direction == "up") ? faderVisualValue > 0.75 : faderVisualValue > 0.15
                    let midiOnFill = (direction == "up") ? faderVisualValue > 0.15 : faderVisualValue > 0.75
                    Text(button.title)
                        .font(.cb(.caption, .bold))
                        .foregroundColor(titleOnFill ? filledTextColor : emptyTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.top, isPhone ? 2 : 4)
                    Spacer()
                    if showMIDIData {
                        Text(midiLabel())
                            .font(.cb(.micro))
                            .foregroundColor((midiOnFill ? filledTextColor : emptyTextColor).opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, isPhone ? 2 : 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false) // Don't interfere with fader drag
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: CBRadius.small).fill(Color.clear))
        .contentShape(Rectangle())  // Ensure entire frame is tappable
        .highPriorityGesture(
            // Only apply TapGesture for buttons, not faders (faders have DragGesture with minimumDistance: 0)
            button.isFader == true ? nil : TapGesture().onEnded {
                if isEditing {
                    onEdit()
                } else {
                    onTap()
                }
            }
        )
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isTouching)
        .animation(.spring(response: 0.15, dampingFraction: 0.75), value: isDragging)
    }

    private func midiLabel() -> String {
        switch button.kind {
        case .cc:   return "\(button.channel)•\(button.number)"
        case .note: return "\(button.channel)•\(button.number)•\(button.velocity)"
        }
    }
}

// MARK: - iPad Drop Delegate (adapted from Mac editor)
struct iPadDropDelegate: DropDelegate {
    let columns: Int
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let cellSize: CGFloat
    let displayRows: Int
    @Binding var buttons: [ControlButton]
    @Binding var dragging: ControlButton?
    @Binding var previewLocation: GridPosition?
    @Binding var dropSurfaceElevated: Bool
    @Binding var isDragOperation: Bool
    @Binding var lastDropTime: Date
    let isActive: Bool
    let clearDragState: (String) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
            // Always return true to prevent 🚫 icon - we'll handle validation in performDrop
            return true
    }
    
    func dropEntered(info: DropInfo) {
        debugPrint("🟦 dropEntered called - isActive: \(isActive), dragging: \(dragging?.title ?? "nil")")
        debugPrint("🟦 dropEntered location: (\(info.location.x), \(info.location.y))")
        guard isActive, dragging != nil else { 
            debugPrint("🔴 dropEntered: not active or no dragging")
            return 
        }
        updatePreview(info: info)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Always update preview, even during fast drags
        updatePreview(info: info)
        // Ensure we maintain drag state during fast movement
        if dragging != nil {
        return DropProposal(operation: .move)
        } else {
            return DropProposal(operation: .forbidden)
        }
    }
    
    func dropExited(info: DropInfo) {
        // Don't clear preview immediately - give a brief moment to return
        // Only clear if we're truly exiting the drop area
        debugPrint("🚪 dropExited: keeping drag state for potential return")
    }
    
    private func updatePreview(info: DropInfo) {
        guard let dragging = dragging else {
            debugPrint("🔴 updatePreview: no dragging item")
            return
        }
        
        let p = info.location
        let rawCol = Int((p.x / (cellSize + columnSpacing)).rounded(.down))
        let rawRow = Int((p.y / (cellSize + rowSpacing)).rounded(.down))
        let row = max(0, min(rawRow, displayRows - 1))

        let targetWidth = dragging.gridWidth
        let col = max(0, min(rawCol, columns - targetWidth))
        
        let fits = col + targetWidth <= columns && row >= 0 && col >= 0

        let newPosition = fits ? GridPosition(col: col, row: row) : nil
        
        // Always update preview location during active drags to handle fast movement
        previewLocation = newPosition
        if let pos = newPosition {
            debugPrint("🟦 Preview updated to: (\(pos.col), \(pos.row))")
        } else {
            debugPrint("🟦 Preview cleared - doesn't fit")
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        debugPrint("✅ performDrop called: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
        guard isActive, let draggingButton = dragging else { 
            debugPrint("🔴 performDrop failed: active=\(isActive), dragging=\(dragging?.title ?? "nil")")
            return false 
        }
        
        let p = info.location
        let rawCol = Int((p.x / (cellSize + columnSpacing)).rounded(.down))
        let rawRow = Int((p.y / (cellSize + rowSpacing)).rounded(.down))
        let row = max(0, min(rawRow, displayRows - 1))
        let targetWidth = draggingButton.gridWidth
        let col = max(0, min(rawCol, columns - targetWidth))
        
        debugPrint("✅ performDrop to (\(col),\(row)) for \(draggingButton.title) - using smart placement")
        
        // Use smart placement to handle overlaps and find best position
        smartPlacement(dragging: draggingButton, targetCol: col, targetRow: row)
        
        // Verify the placement was successful
        if let buttonIndex = buttons.firstIndex(where: { $0.id == draggingButton.id }) {
            let finalCol = buttons[buttonIndex].gridCol ?? -1
            let finalRow = buttons[buttonIndex].gridRow ?? -1
            debugPrint("✅ Final position for \(draggingButton.title): (\(finalCol), \(finalRow))")
        }
        
        // Record drop time to prevent auto-assignment interference
        lastDropTime = Date()
        
        // Add a small delay before clearing drag state to ensure position is committed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            clearDragState("drop completed successfully")
        }
        return true
    }
    
    // Smart placement helper functions (from Mac editor)
    private func smartPlacement(dragging: ControlButton, targetCol: Int, targetRow: Int) {
            let draggedWidth = dragging.gridWidth
            let draggedHeight = dragging.gridHeight
        guard let draggedIndex = buttons.firstIndex(where: { $0.id == dragging.id }) else { 
            debugPrint("🔴 smartPlacement: Could not find dragged button \(dragging.title) in buttons array")
            return 
        }
        
        let _ = buttons[draggedIndex].gridCol ?? -1
        let _ = buttons[draggedIndex].gridRow ?? -1
        // Removed verbose height calculation logs for cleaner testing
        debugPrint("🔍 smartPlacement: buttons array has \(buttons.count) items, draggedIndex = \(draggedIndex)")
        
        buttons[draggedIndex].gridCol = nil
        buttons[draggedIndex].gridRow = nil
        let draggedRect = GridRect(col: targetCol, row: targetRow, width: draggedWidth, height: draggedHeight)
        let overlapping = findOverlappingItems(for: draggedRect)
        if overlapping.isEmpty {
            buttons[draggedIndex].gridCol = targetCol
            buttons[draggedIndex].gridRow = targetRow
            debugPrint("✅ smartPlacement: Placed \(dragging.title) at (\(targetCol), \(targetRow)) - no overlaps")
        } else {
            var displacedItems: [(index: Int, originalCol: Int, originalRow: Int, item: ControlButton)] = []
            for overlappingIndex in overlapping {
                let originalCol = buttons[overlappingIndex].gridCol ?? 0
                let originalRow = buttons[overlappingIndex].gridRow ?? 0
                displacedItems.append((index: overlappingIndex, originalCol: originalCol, originalRow: originalRow, item: buttons[overlappingIndex]))
                buttons[overlappingIndex].gridCol = nil
                buttons[overlappingIndex].gridRow = nil
            }
            buttons[draggedIndex].gridCol = targetCol
            buttons[draggedIndex].gridRow = targetRow
            debugPrint("✅ smartPlacement: Placed \(dragging.title) at (\(targetCol), \(targetRow)) - handling \(displacedItems.count) overlaps")
            // Use iPhone-like smart positioning for displaced items
            for (index, originalCol, originalRow, item) in displacedItems {
                let itemWidth = item.gridWidth
                let itemHeight = item.gridHeight

                // Try to find a smart position (right first, then down)
                if let newPos = findSmartPosition(
                    forItemAt: (originalCol, originalRow),
                    width: itemWidth,
                    height: itemHeight,
                    excluding: index
                ) {
                    buttons[index].gridCol = newPos.col
                    buttons[index].gridRow = newPos.row
                    debugPrint("🔄 Displaced \(item.title) to new position (\(newPos.col), \(newPos.row))")
                } else {
                    buttons[index].gridCol = originalCol
                    buttons[index].gridRow = originalRow
                    debugPrint("⚠️ Could not find new position for \(item.title), keeping at original (\(originalCol), \(originalRow))")
                }
            }
        }
    }
    
    private func findOverlappingItems(for rect: GridRect) -> [Int] {
        var overlapping: [Int] = []
        for (index, item) in buttons.enumerated() {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                    width: item.gridWidth,
                    height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) {
                    debugPrint("🔍 Found overlap: \(item.title) at (\(col),\(row)) size \(itemRect.width)x\(itemRect.height) overlaps with target rect (\(rect.col),\(rect.row)) size \(rect.width)x\(rect.height)")
                overlapping.append(index)
            }
        }
        return overlapping
    }
    
    private func findFreePosition(width: Int, height: Int) -> (col: Int, row: Int)? {
        let maxSearchRows = 4
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                    if !hasOverlap(testRect) { return (col: col, row: row) }
                }
            }
        return nil
    }

    // iPhone-like smart positioning: prioritize right, then down, then general search
    private func findSmartPosition(
        forItemAt originalPos: (Int, Int),
        width: Int,
        height: Int,
        excluding excludeIndex: Int
    ) -> (col: Int, row: Int)? {
        let (originalCol, originalRow) = originalPos

        // 1. Try moving right first (same row, next column)
        let rightCol = originalCol + 1
        if rightCol + width <= columns {
            let testRect = GridRect(col: rightCol, row: originalRow, width: width, height: height)
            if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                return (rightCol, originalRow)
            }
        }

        // 2. Try moving down and left (cascade to next row)
        let nextRow = originalRow + 1
        if nextRow + height <= 4 { // max 4 rows
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: nextRow, width: width, height: height)
                if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                    return (col, nextRow)
                }
            }
        }

        // 3. Fallback to general search (left-to-right, top-to-bottom)
        return findFreePositionExcluding(width: width, height: height, excluding: excludeIndex)
    }

    private func findFreePositionExcluding(width: Int, height: Int, excluding excludeIndex: Int) -> (col: Int, row: Int)? {
        let maxSearchRows = 4
        for row in 0..<maxSearchRows {
            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                if !hasOverlapExcluding(testRect, excluding: excludeIndex) {
                    return (col: col, row: row)
                }
            }
        }
        return nil
    }

    private func hasOverlapExcluding(_ rect: GridRect, excluding excludeIndex: Int) -> Bool {
        for (index, item) in buttons.enumerated() {
            if index == excludeIndex { continue }
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }
    
    private func hasOverlap(_ rect: GridRect) -> Bool {
        for item in buttons {
            guard let col = item.gridCol, let row = item.gridRow else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                    width: item.gridWidth,
                    height: item.gridHeight
            )
                if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }
    
    private func rectsOverlap(_ rect1: GridRect, _ rect2: GridRect) -> Bool {
        return !(rect1.col + rect1.width <= rect2.col ||
                rect2.col + rect2.width <= rect1.col ||
                rect1.row + rect1.height <= rect2.row ||
                rect2.row + rect2.height <= rect1.row)
    }
}
