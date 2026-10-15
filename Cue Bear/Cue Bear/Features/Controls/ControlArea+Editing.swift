//
//  ControlArea+Editing.swift — Cue Bear
//  CBControlSection: Cross-Page Drag
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension CBControlSection {
    // MARK: - Cross-Page Drag Handling

    /// Check if drag position is at the edge and start/stop timer accordingly
    func checkEdgeDrag(dragX: CGFloat, gridWidth: CGFloat) {
        let leftEdge = dragX < edgeThreshold
        let rightEdge = dragX > gridWidth - edgeThreshold

        if leftEdge && currentPage > 0 {
            // At left edge - can go to previous page
            if edgeDragDirection != -1 {
                startEdgeDragTimer(direction: -1)
            }
        } else if rightEdge && currentPage < totalPages - 1 {
            // At right edge - can go to next page
            if edgeDragDirection != 1 {
                startEdgeDragTimer(direction: 1)
            }
        } else {
            // Not at edge - cancel timer
            cancelEdgeDragTimer()
        }
    }

    func startEdgeDragTimer(direction: Int) {
        cancelEdgeDragTimer()
        edgeDragDirection = direction
        edgeDragTimer = Timer.scheduledTimer(withTimeInterval: edgeDragDelay, repeats: false) { [self] _ in
            // Move control to adjacent page
            if let draggedButton = dragging {
                moveControlToPage(draggedButton, newPage: currentPage + direction)
            }
        }
    }

    func cancelEdgeDragTimer() {
        edgeDragTimer?.invalidate()
        edgeDragTimer = nil
        edgeDragDirection = 0
    }

    /// Move a control to a different page and switch to that page
    func moveControlToPage(_ control: ControlButton, newPage: Int) {
        guard newPage >= 0 && newPage < totalPages else { return }

        // Update the control's page
        if let index = buttons.firstIndex(where: { $0.id == control.id }) {
            buttons[index].page = newPage
            // Reset grid position to find a new spot on the new page
            buttons[index].gridCol = nil
            buttons[index].gridRow = nil
        }

        // Switch to the new page
        withAnimation(.easeInOut(duration: 0.2)) {
            currentPage = newPage
        }

        // Reset drag state
        clearDragState(reason: "moved control to page \(newPage)")
        cancelEdgeDragTimer()

        // Trigger re-layout
        editSessionNonce &+= 1
    }

    func controlRowCount() -> Int {
        let slotsPerRow = max(3, perRow * 3)
        let totalSlots = buttons.reduce(0) { acc, b in acc + (b.isFader == true ? 2 : 3) }
        return Int(ceil(Double(max(1, totalSlots)) / Double(slotsPerRow)))
    }

    var collapsedView: some View {
        Group {
            if buttons.isEmpty && !isEditing {
                // Show floating Edit button capsule when no controls exist
                Color.clear
                    .frame(height: 0)
                    .overlay(alignment: .bottomTrailing) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isEditing = true
                                isCollapsed = false
                                editSessionNonce &+= 1
                            }
                        }) {
                            Text("Edit")
                                .font(.cb(.body, .medium))
                                .foregroundStyle(standardButtonColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .cbChip()
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom))
            } else {
                // Show small collapsed capsule on right when collapsed
                Color.clear
                    .frame(height: 0)
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 0) {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    if isEditing {
                                        isEditing = false
                                        clearDragState(reason: "done button in collapsed capsule")
                                    } else {
                                        isEditing = true
                                        isCollapsed = false
                                        editSessionNonce &+= 1
                                    }
                                }
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                                    .font(.cb(.body, .medium))
                                    .foregroundStyle(CBColor.textPrimary)
                                    .padding(.horizontal, 12)
                                    .frame(height: 44)
                            }
                            .buttonStyle(IOSPressButtonStyle())

                            if !buttons.isEmpty {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        isCollapsed = false
                                    }
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(.cbIcon(.body, .semibold))
                                        .foregroundStyle(CBColor.textPrimary)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(IOSPressButtonStyle())
                            }
                        }
                        .cbChip()
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom))
            }
        }
        .onChange(of: isEditing) { _, editing in
            clearDragState(reason: "edit mode toggle")
        }
        .onAppear {
            canAddMoreControls = canAddMoreControlsGlobal
        }
        .onChange(of: buttons.count) { _, _ in
            canAddMoreControls = canAddMoreControlsGlobal
        }
    }

    var headerView: some View {
        VStack(spacing: 0) {
            mainHeader
        }
    }

    
    var collapseHandle: some View {
        Button(action: {
            // Only allow toggle if there are buttons in the control area
            if !buttons.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCollapsed.toggle()
                }
            }
        }) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(buttons.isEmpty ? 0.15 : 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(buttons.isEmpty)
    }

    
    var mainHeader: some View {
        HStack(spacing: 8) {
            // Page navigation capsule (left side) - show if:
            // 1. More than 1 page has controls, OR
            // 2. In edit mode with multiple pages available, OR
            // 3. There are any buttons (show page indicator even if all on one page)
            if pagesWithControls.count > 1 || (isEditing && availablePages.count > 1) || !buttons.isEmpty {
                HStack(spacing: 0) {
                    // Previous page button
                    Button(action: {
                        if let prev = previousPage {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentPage = prev
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.cbIcon(.body, .medium))
                            .foregroundColor(previousPage != nil ? .white : .white.opacity(0.3))
                            .frame(width: 36, height: 44)
                    }
                    .disabled(previousPage == nil)

                    // Page indicator
                    Text(pageIndicatorText)
                        .font(.cb(.small))
                        .foregroundStyle(CBColor.textPrimary)
                        .frame(minWidth: 32)

                    // Next page button
                    Button(action: {
                        if let next = nextPage {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentPage = next
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.cbIcon(.body, .medium))
                            .foregroundColor(nextPage != nil ? .white : .white.opacity(0.3))
                            .frame(width: 36, height: 44)
                    }
                    .disabled(nextPage == nil)
                }
                .cbChip()
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: CBRadius.control))
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let horizontalAmount = value.translation.width
                            // Swipe left = next page, swipe right = previous page
                            if horizontalAmount < -30, let next = nextPage {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPage = next
                                }
                            } else if horizontalAmount > 30, let prev = previousPage {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPage = prev
                                }
                            }
                        }
                )
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Edit mode: 3 separate capsules (undo/redo | + | done)
            // Non-edit mode: single "Edit" capsule
            if isEditing && !isCollapsed {
                // Capsule 3 (leftmost): Undo/Redo
                HStack(spacing: 0) {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.cbIcon(.large, .medium))
                            .foregroundColor(canUndo ? .white : .white.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canUndo)

                    Button(action: onRedo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.cbIcon(.large, .medium))
                            .foregroundColor(canRedo ? .white : .white.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canRedo)
                }
                .cbChip()
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .transition(.scale.combined(with: .opacity))

                // Capsule 2 (middle): Add (+)
                Menu {
                    Button(action: onAddButton) {
                        Label("Button", systemImage: "button.horizontal")
                    }
                    .disabled(!canAddMoreControls)

                    Button(action: onAddFader) {
                        Label("Fader", systemImage: "slider.vertical.3")
                    }
                    .disabled(!canAddFader)
                } label: {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.cbIcon(.large, .medium))
                                .foregroundColor((canAddMoreControls || canAddFader) ? .white : .white.opacity(0.3))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canAddMoreControls && !canAddFader)
                .frame(width: 44, height: 44)
                .cbChip()
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                .transition(.scale.combined(with: .opacity))
            }

            // Rightmost capsule: always present, no conditional insertion
            // Non-edit mode with buttons: [Edit | ▼] combined capsule
            // Non-edit mode no buttons: [Edit] single button
            // Edit mode: [✓] done button
            HStack(spacing: 0) {
                if isEditing && !isCollapsed {
                    // Done button (checkmark or collapse chevron if empty)
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if buttons.isEmpty {
                                isCollapsed = true
                                isEditing = false
                                clearDragState(reason: "main edit button - collapsing empty control area")
                            } else {
                                isEditing = false
                                clearDragState(reason: "main edit button - exiting edit mode")
                            }
                        }
                    }) {
                        Image(systemName: buttons.isEmpty ? "chevron.down" : "checkmark")
                            .font(.cbIcon(.large, .medium))
                            .foregroundStyle(CBColor.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Edit button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isEditing = true
                            isCollapsed = false
                            selectedCue = nil
                            editSessionNonce &+= 1
                            clearDragState(reason: "main edit button - entering edit mode")
                        }
                    }) {
                        Text("Edit")
                            .font(.cb(.body))
                            .foregroundStyle(CBColor.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)

                    // Collapse chevron — always here when Edit is shown + buttons exist
                    // No conditional insertion = no transition animation issues
                    if !buttons.isEmpty {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 24)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isCollapsed.toggle()
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.cbIcon(.body, .medium))
                                .foregroundStyle(CBColor.textPrimary)
                                .frame(width: 40, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .cbChip()
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(height: 68)
    }

    
    // Treat empty as collapsed (when not editing)
    var effectivelyCollapsed: Bool {
        return isCollapsed || (buttons.isEmpty && !isEditing)
    }

    // Calculate dynamic height without needing GeometryProxy
    func calculateDynamicHeight() -> CGFloat {
        // Use tracked actual width instead of screen bounds for proper orientation handling
        let height = calculateControlAreaHeight(proxy: nil, screenWidth: actualWidth)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone {
            debugPrint("📱 [calculateDynamicHeight] height=\(height), actualWidth=\(actualWidth)")
        }
        return height
    }

    
    // Calculate the height needed for the control area
    func calculateControlAreaHeight(proxy: GeometryProxy?, screenWidth: CGFloat? = nil) -> CGFloat {
        let isLandscape = verticalSizeClass == .compact
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        // iPhone: Dynamic height based on content, with larger cells
        // Always use 80% of landscape height (the shorter dimension) for consistency
        // NOTE: This returns GRID HEIGHT ONLY - header is added separately in VStack
        if isPhone {
            // IMPORTANT: Use globalCachedPortraitWidth instead of UIScreen.main.bounds
            // Accessing UIScreen.main.bounds during SwiftUI layout causes freeze
            let landscapeHeight = globalCachedPortraitWidth  // Already the shorter dimension
            let maxAvailableHeight = landscapeHeight * 0.8

            // Reserve space for header (68pt is added separately) and grid padding
            let headerHeight: CGFloat = 68
            let gridVerticalPadding: CGFloat = 52  // 8pt top + 12pt bottom + scrollbar (28pt handle + 4pt bottom padding)
            let maxGridAreaHeight = maxAvailableHeight - headerHeight - gridVerticalPadding

            // Calculate cell size based on 4 rows max - NO MINIMUM, let it shrink to fit
            let maxRows = 4
            let verticalGapsMax = max(0, maxRows - 1)
            let cellSize = floor((maxGridAreaHeight - CGFloat(verticalGapsMax) * rowSpacing) / CGFloat(maxRows))

            // Determine actual rows needed
            let rows: Int
            if isEditing {
                rows = 4  // Full grid in edit mode
            } else {
                let visualRows = calculateVisualRows()
                let pageButtons = buttons.filter { $0.page == currentPage }
                if visualRows == 0 && pageButtons.isEmpty {
                    return 44  // Header-only height when no buttons (this is total height)
                }
                rows = min(4, max(1, visualRows))
            }

            // Calculate GRID height only (header is in separate view in VStack)
            let verticalGaps = max(0, rows - 1)
            let gridHeight = CGFloat(rows) * cellSize + CGFloat(verticalGaps) * rowSpacing + gridVerticalPadding

            debugPrint("📱 [iPhone height] landscapeH=\(landscapeHeight), maxAvail=\(maxAvailableHeight), cellSize=\(cellSize), rows=\(rows), gridHeight=\(gridHeight)")

            return gridHeight
        }

        // iPad: Calculate based on grid dimensions
        let fixedWidthForGrid: CGFloat = portraitWidth

        let width: CGFloat = fixedWidthForGrid
        let totalSpacing = CGFloat(columns - 1) * columnSpacing
        let actualHorizontalPadding = gridPadding
        let availableWidth = width - (2 * actualHorizontalPadding) - totalSpacing
        let cellSize = floor(availableWidth / CGFloat(columns))

        // Ensure minimum cell size in landscape to prevent cutoff
        let minCellSize: CGFloat = isLandscape ? 80 : 60
        let adjustedCellSize = max(cellSize, minCellSize)

        // Determine rows based on mode and orientation
        let rows: Int

        if isEditing {
            // Edit mode: Always show full 4-row editing canvas
            rows = 4
        } else {
            // Non-edit mode: Dynamic based on occupied buttons on current page, capped at 4 rows
            let visualRows = calculateVisualRows()
            let pageButtons = buttons.filter { $0.page == currentPage }
            if visualRows == 0 && pageButtons.isEmpty {
                // Special case: no buttons on current page = header-only height (same as collapsed)
                return 44
            }
            rows = min(4, max(0, visualRows))
        }

        // Convert rows to pixels
        let verticalGaps = max(0, rows - 1)
        let gridHeight = CGFloat(rows) * adjustedCellSize + CGFloat(verticalGaps) * rowSpacing

        // Add extra padding in landscape to prevent cutoff and provide breathing room
        let extraPadding: CGFloat = isLandscape ? 30 : 0
        // iPad: top=8, bottom=gridPadding (same as sides)
        let actualVerticalPadding: CGFloat = 8 + gridPadding
        let finalHeight = gridHeight + actualVerticalPadding + extraPadding

        return finalHeight
    }

    
    // Calculate visual rows based on actual control positions and sizes (for current page only)
    func calculateVisualRows() -> Int {
        // Only count buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        guard !pageButtons.isEmpty else {
            return 0  // Will be handled specially in height calculation
        }

        // Don't call autoAssignGridPositions during view updates to avoid state modification warnings
        // Instead, just calculate based on current positions, defaulting to row 0 if not set

        var maxEndRow = 0
        for button in pageButtons {
            let row = button.gridRow ?? 0  // Default to row 0 if not assigned yet
            // Use button.gridHeight to get the correct height based on orientation
            let height = button.gridHeight
            let endRow = row + height
            maxEndRow = max(maxEndRow, endRow)
        }

        let result = maxEndRow  // Allow 0 rows for minimal height when no buttons
        return result
    }

    
    // Legacy function kept for compatibility
    func calculateOccupiedRows() -> Int {
        return calculateVisualRows()
    }

    
    // Auto-assign grid positions for controls that don't have them
    func autoAssignGridPositions() {
        var needsUpdate = false
        var updates: [(Int, Int, Int)] = [] // (index, col, row)
        var occupiedPositions: Set<String> = [] // Track occupied positions as "col,row"

        // First, record all existing positions to avoid conflicts
        for button in buttons {
            if let col = button.gridCol, let row = button.gridRow {
                let width = button.gridWidth
                let height = button.gridHeight

                // Mark all cells occupied by this button
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }

        for i in 0..<buttons.count {
            // Only assign if not already set - don't override user-placed positions
            let needsPosition = buttons[i].gridCol == nil || buttons[i].gridRow == nil
            
            if needsPosition {
                if let position = findFirstAvailablePositionAvoidingOccupied(for: buttons[i], occupied: occupiedPositions) {
                    updates.append((i, position.col, position.row))
                    needsUpdate = true

                    // Update occupied positions for next iteration
                    let width = buttons[i].gridWidth
                    let height = buttons[i].gridHeight
                    for c in position.col..<(position.col + width) {
                        for r in position.row..<(position.row + height) {
                            occupiedPositions.insert("\(c),\(r)")
                        }
                    }
                } else {
                    // Fallback: place at bottom in first available column
                    let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
                    let fallbackRow = maxRow + 2 // Give some space
                    updates.append((i, 0, fallbackRow))
                    needsUpdate = true
                }
            }
        }

        // Apply updates on next run loop to avoid "modifying state during view update"
        if needsUpdate {
            DispatchQueue.main.async {
                for (index, col, row) in updates {
                    if index < self.buttons.count {
                        self.buttons[index].gridCol = col
                        self.buttons[index].gridRow = row
                    }
                }
            }
        }
    }

    
    // Check if a button overlaps with any other buttons
    func checkForOverlap(button: ControlButton, excluding excludeIds: [UUID]) -> Bool {
        guard let col = button.gridCol, let row = button.gridRow else { return false }

        let width = button.gridWidth
        let height = button.gridHeight
        let buttonRect = GridRect(col: col, row: row, width: width, height: height)
        
        let hasOverlap = hasOverlapExcluding(buttonRect, excluding: excludeIds)
        if hasOverlap {
            debugPrint("🔍 Overlap detected for \(button.title) at (\(col), \(row)) size \(width)x\(height)")
        }
        return hasOverlap
    }

    
    // Find first available position avoiding already occupied positions
    func findFirstAvailablePositionAvoidingOccupied(for control: ControlButton, occupied: Set<String>) -> (col: Int, row: Int)? {
        let width = control.gridWidth
        let height = control.gridHeight
        let maxSearchRows = 4 // Reasonable limit

        // Search from top-left to bottom-right
        for row in 0..<maxSearchRows {
            // Skip this row if the control would extend beyond the bottom edge
            if row + height > maxSearchRows {
                continue
            }

            for col in 0...(columns - width) {
                var canPlace = true

                // Check if all required cells are free
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        if occupied.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, row)
                }
            }
        }
        return nil
    }

    
    // Find the first available position for a control (top-left to bottom-right priority)
    func findFirstAvailablePosition(for control: ControlButton) -> (col: Int, row: Int)? {
        let width = control.gridWidth
        let height = control.gridHeight
        let maxSearchRows = 4

        // Search from top-left to bottom-right
        for row in 0..<maxSearchRows {
            // Skip this row if the control would extend beyond the bottom edge
            if row + height > maxSearchRows {
                continue
            }

            for col in 0...(columns - width) {
                let testRect = GridRect(col: col, row: row, width: width, height: height)
                let hasOverlap = hasOverlapExcluding(testRect, excluding: [control.id])
                if !hasOverlap {
                    return (col, row)
                }
            }
        }
        return nil
    }

    // Compute effective position for live displacement preview during drag
    func effectivePosition(
        for button: ControlButton,
        dragging: ControlButton?,
        preview: GridPosition?,
        columns: Int
    ) -> (col: Int, row: Int) {
        let baseCol = button.gridCol ?? 0
        let baseRow = button.gridRow ?? 0
        guard let dragging = dragging, let preview = preview else {
            return (baseCol, baseRow)
        }

        // If this IS the dragged button, keep it at its original position
        // The dragTranslation offset will handle the visual movement
        if dragging.id == button.id {
            return (baseCol, baseRow)
        }

        // PERFORMANCE FIX: Generate cache key for current drag state
        let cacheKey = "\(dragging.id)_\(preview.col)_\(preview.row)"

        // PERFORMANCE FIX: Check if we need to rebuild cache (but don't modify state here!)
        // If cache is stale, compute on-the-fly. Cache will be updated via onChange modifier.
        if displacementCacheKey != cacheKey {
            // Cache is stale - compute directly without modifying state
            let result = computeAllDisplacements(draggedButton: dragging, targetPosition: preview, columns: columns)
            return result.displacements[button.id] ?? (baseCol, baseRow)
        }

        // PERFORMANCE FIX: Use cached result (O(1) lookup instead of O(n) computation)
        if let cachedPos = displacementCache[button.id] {
            return cachedPos
        }

        return (baseCol, baseRow)
    }

    // PERFORMANCE FIX: Compute all displacement positions at once (called once per preview location change)
    func computeAllDisplacements(draggedButton: ControlButton, targetPosition: GridPosition, columns: Int) -> (displacements: [UUID: (col: Int, row: Int)], hasInvalidDisplacement: Bool) {
        var result: [UUID: (col: Int, row: Int)] = [:]
        var hasInvalidDisplacement = false

        let draggedW = draggedButton.gridWidth
        let draggedH = draggedButton.gridHeight
        let draggedButtonShadow = GridRect(col: targetPosition.col, row: targetPosition.row, width: draggedW, height: draggedH)

        // Build occupancy map once for all buttons
        var occupiedPositions: Set<String> = []

        // Mark the dragged button's new position as occupied
        for c in targetPosition.col..<(targetPosition.col + draggedW) {
            for r in targetPosition.row..<(targetPosition.row + draggedH) {
                occupiedPositions.insert("\(c),\(r)")
            }
        }

        // Mark all existing button positions as occupied (excluding dragged button)
        for otherButton in buttons {
            if otherButton.id == draggedButton.id { continue }

            if let col = otherButton.gridCol, let row = otherButton.gridRow {
                let width = otherButton.gridWidth
                let height = otherButton.gridHeight
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }

        // Now compute displacement for each button that overlaps
        for button in buttons {
            if button.id == draggedButton.id { continue }

            let baseCol = button.gridCol ?? 0
            let baseRow = button.gridRow ?? 0
            let buttonRect = GridRect(col: baseCol, row: baseRow, width: button.gridWidth, height: button.gridHeight)

            if rectsOverlap(buttonRect, draggedButtonShadow) {
                // This button needs to move - calculate its new position
                let newPos = calculateDisplacementPosition(
                    for: button,
                    draggedButton: draggedButton,
                    targetPosition: targetPosition,
                    columns: columns,
                    occupiedPositions: occupiedPositions
                )

                if let validPos = newPos {
                    result[button.id] = validPos
                } else {
                    // No valid position found - keep button in original position and mark as invalid
                    hasInvalidDisplacement = true
                    result[button.id] = (baseCol, baseRow)
                }
            }
        }

        return (displacements: result, hasInvalidDisplacement: hasInvalidDisplacement)
    }

    
    // PERFORMANCE FIX: Calculate displacement position using pre-computed occupancy map
    func calculateDisplacementPosition(
        for button: ControlButton,
        draggedButton: ControlButton,
        targetPosition: GridPosition,
        columns: Int,
        occupiedPositions: Set<String>
    ) -> (col: Int, row: Int)? {
        let buttonW = button.gridWidth
        let buttonH = button.gridHeight
        let draggedOriginalCol = draggedButton.gridCol ?? 0
        let draggedOriginalRow = draggedButton.gridRow ?? 0

        // Create a mutable copy to track positions occupied by other displaced buttons
        var mutableOccupied = occupiedPositions

        // Remove this button's current position from occupancy check
        if let col = button.gridCol, let row = button.gridRow {
            for c in col..<(col + buttonW) {
                for r in row..<(row + buttonH) {
                    mutableOccupied.remove("\(c),\(r)")
                }
            }
        }

        // iPhone-like smart positioning: try positions in order of preference
        // 1. Try swapping with dragged button's original position first (simple swap)

        if draggedOriginalCol + buttonW <= columns {
            var canSwap = true
            for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                    if occupiedPositions.contains("\(c),\(r)") {
                        canSwap = false
                        break
                    }
                }
                if !canSwap { break }
            }

            if canSwap {
                return (draggedOriginalCol, draggedOriginalRow)
            }
        }

        // 2. Try moving right first (same row, next column) - iPhone behavior
        let originalCol = button.gridCol ?? 0
        let originalRow = button.gridRow ?? 0
        let rightCol = originalCol + 1

        if rightCol + buttonW <= columns {
            var canMoveRight = true
            for c in rightCol..<(rightCol + buttonW) {
                for r in originalRow..<(originalRow + buttonH) {
                    if occupiedPositions.contains("\(c),\(r)") {
                        canMoveRight = false
                        break
                    }
                }
                if !canMoveRight { break }
            }

            if canMoveRight {
                return (rightCol, originalRow)
            }
        }

        // 3. Try moving down and left (cascade to next row) - iPhone behavior
        let nextRow = originalRow + 1
        if nextRow + buttonH <= 4 { // max rows check
            for col in 0...(columns - buttonW) {
                var canPlace = true
                for c in col..<(col + buttonW) {
                    for r in nextRow..<(nextRow + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, nextRow)
                }
            }
        }

        // 4. Fallback: find the next available position (top-left to bottom-right)
        let maxRows = 4
        for row in 0..<maxRows {
            for col in 0...(columns - buttonW) {
                var canPlace = true
                for c in col..<(col + buttonW) {
                    for r in row..<(row + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canPlace = false
                            break
                        }
                    }
                    if !canPlace { break }
                }

                if canPlace {
                    return (col, row)
                }
            }
        }

        // No valid position found - return nil to signal "no space available"
        return nil
    }

    
    // Commit positions for all buttons that were displaced during the drag
    func commitDisplacedButtonPositions(draggedButton: ControlButton, targetPosition: GridPosition) {
        let draggedW = draggedButton.gridWidth
        let draggedH = draggedButton.gridHeight
        let draggedButtonShadow = GridRect(col: targetPosition.col, row: targetPosition.row, width: draggedW, height: draggedH)
        
        // Find all buttons that were displaced
        var displacedButtons: [(Int, ControlButton)] = []
        for i in 0..<buttons.count {
            let button = buttons[i]
            if button.id == draggedButton.id { continue } // Skip the dragged button
            
            let buttonRect = GridRect(
                col: button.gridCol ?? 0,
                row: button.gridRow ?? 0,
                width: button.gridWidth,
                height: button.gridHeight
            )
            
            // If this button was displaced (overlapped with the dragged button's shadow)
            if rectsOverlap(buttonRect, draggedButtonShadow) {
                displacedButtons.append((i, button))
            }
        }
        
        // Assign unique positions to displaced buttons
        var occupiedPositions: Set<String> = []
        
        // First, mark the dragged button's new position as occupied
        for c in targetPosition.col..<(targetPosition.col + draggedW) {
            for r in targetPosition.row..<(targetPosition.row + draggedH) {
                occupiedPositions.insert("\(c),\(r)")
            }
        }
        
        // Mark all existing button positions as occupied (excluding displaced buttons)
        for i in 0..<buttons.count {
            let button = buttons[i]
            if button.id == draggedButton.id { continue }
            if displacedButtons.contains(where: { $0.1.id == button.id }) { continue }
            
            if let col = button.gridCol, let row = button.gridRow {
                let width = button.gridWidth
                let height = button.gridHeight
                for c in col..<(col + width) {
                    for r in row..<(row + height) {
                        occupiedPositions.insert("\(c),\(r)")
                    }
                }
            }
        }
        
        // Assign unique positions to displaced buttons
        for (index, button) in displacedButtons {
            let buttonW = button.gridWidth
            let buttonH = button.gridHeight
            
            // Try swapping with dragged button's original position first
            let draggedOriginalCol = draggedButton.gridCol ?? 0
            let draggedOriginalRow = draggedButton.gridRow ?? 0
            
            var foundPosition = false
            if draggedOriginalCol + buttonW <= columns {
                var canSwap = true
                for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                    for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                        if occupiedPositions.contains("\(c),\(r)") {
                            canSwap = false
                            break
                        }
                    }
                    if !canSwap { break }
                }
                
                if canSwap {
                    buttons[index].gridCol = draggedOriginalCol
                    buttons[index].gridRow = draggedOriginalRow
                    foundPosition = true
                    debugPrint("🔄 Committed displaced button \(button.title) to swapped position (\(draggedOriginalCol), \(draggedOriginalRow))")
                    
                    // Mark this position as occupied
                    for c in draggedOriginalCol..<(draggedOriginalCol + buttonW) {
                        for r in draggedOriginalRow..<(draggedOriginalRow + buttonH) {
                            occupiedPositions.insert("\(c),\(r)")
                        }
                    }
                }
            }
            
            // If swap didn't work, find the next available position
            if !foundPosition {
                let maxRows = 4
                for row in 0..<maxRows {
                    for col in 0...(columns - buttonW) {
                        var canPlace = true
                        for c in col..<(col + buttonW) {
                            for r in row..<(row + buttonH) {
                                if occupiedPositions.contains("\(c),\(r)") {
                                    canPlace = false
                                    break
                                }
                            }
                            if !canPlace { break }
                        }
                        
                        if canPlace {
                            buttons[index].gridCol = col
                            buttons[index].gridRow = row
                            foundPosition = true
                            debugPrint("🔄 Committed displaced button \(button.title) to (\(col), \(row))")
                            
                            // Mark this position as occupied
                            for c in col..<(col + buttonW) {
                                for r in row..<(row + buttonH) {
                                    occupiedPositions.insert("\(c),\(r)")
                                }
                            }
                            break
                        }
                    }
                    if foundPosition { break }
                }
            }
            
            // Fallback if no position found
            if !foundPosition {
                let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
                buttons[index].gridCol = 0
                buttons[index].gridRow = maxRow + 2
                debugPrint("🔄 Committed displaced button \(button.title) to fallback position (0, \(maxRow + 2))")
            }
        }
    }

    
    // Find displacement position for a button, ensuring no conflicts with other displaced buttons
    func findDisplacementPosition(for button: ControlButton, draggedButton: ControlButton, columns: Int) -> (col: Int, row: Int) {
        let buttonW = button.gridWidth
        let buttonH = button.gridHeight
        
        // First try swapping with the dragged button's original position
        let draggedOriginalCol = draggedButton.gridCol ?? 0
        let draggedOriginalRow = draggedButton.gridRow ?? 0
        let draggedOriginalRect = GridRect(col: draggedOriginalCol, row: draggedOriginalRow, width: buttonW, height: buttonH)
        
        if draggedOriginalCol + buttonW <= columns && !hasOverlapExcluding(draggedOriginalRect, excluding: [draggedButton.id, button.id]) {
            return (draggedOriginalCol, draggedOriginalRow)
        }
        
        // Find a unique position by using the button's index as a seed
        let buttonIndex = buttons.firstIndex(where: { $0.id == button.id }) ?? 0
        let maxRows = 4
        
        // Try positions in a deterministic order based on button index
        // Start the search from a different position based on button index to ensure uniqueness
        let startOffset = buttonIndex * 3 // Use button index to offset the search
        for offset in startOffset..<(maxRows * columns + startOffset) {
            let actualOffset = offset % (maxRows * columns)
            let row = actualOffset / columns
            let col = actualOffset % columns
            
            // Skip if this position would go out of bounds
            if col + buttonW > columns || row + buttonH > maxRows {
                continue
            }
            
            let testRect = GridRect(col: col, row: row, width: buttonW, height: buttonH)
            
            // Check if this position is available (excluding dragged button and this button)
            if !hasOverlapExcluding(testRect, excluding: [draggedButton.id, button.id]) {
                return (col, row)
            }
        }
        
        // Fallback: place at bottom
        let maxRow = buttons.compactMap { $0.gridRow }.max() ?? 0
        return (0, maxRow + 2)
    }

    // Visual-only overlap helpers for live displacement preview
    func rectsOverlap(_ rect1: GridRect, _ rect2: GridRect) -> Bool {
        return !(rect1.col + rect1.width <= rect2.col ||
                 rect2.col + rect2.width <= rect1.col ||
                 rect1.row + rect1.height <= rect2.row ||
                 rect2.row + rect2.height <= rect1.row)
    }

    func hasOverlap(_ rect: GridRect) -> Bool {
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

    func hasOverlapExcluding(_ rect: GridRect, excluding excludeIds: [UUID]) -> Bool {
        // Only check buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        for item in pageButtons {
            guard let col = item.gridCol, let row = item.gridRow, !excludeIds.contains(item.id) else { continue }
            let itemRect = GridRect(
                col: col, row: row,
                width: item.gridWidth,
                height: item.gridHeight
            )
            if rectsOverlap(rect, itemRect) { return true }
        }
        return false
    }

    func findFreePositionVisual(for item: ControlButton, columns: Int, excluding excludeIds: [UUID] = []) -> (col: Int, row: Int)? {
        let width = item.gridWidth
        let height = item.gridHeight
        let maxSearchRows = 4 // Increased search area
        for row in 0..<maxSearchRows {
            // Skip this row if the control would extend beyond the bottom edge
            if row + height > maxSearchRows {
                continue
            }
            for col in 0...(columns - width) {
                let test = GridRect(col: col, row: row, width: width, height: height)
                if !hasOverlapExcluding(test, excluding: excludeIds) {
                    return (col, row)
                }
            }
        }
        return nil
    }

    // Find the nearest available position for a button to move to, avoiding the dragged button's shadow
    func findNearestAvailablePosition(
        for button: ControlButton,
        avoiding draggedButtonShadow: GridRect,
        maxRows: Int,
        columns: Int
    ) -> GridPosition? {
        let buttonWidth = button.gridWidth
        let buttonHeight = button.gridHeight
        
        // Start with the current position
        let currentPos = GridPosition(col: button.gridCol ?? 0, row: button.gridRow ?? 0)
        
        // If current position doesn't overlap with shadow, keep it
        let currentRect = GridRect(col: currentPos.col, row: currentPos.row, width: buttonWidth, height: buttonHeight)
        if !rectsOverlap(currentRect, draggedButtonShadow) {
            return currentPos
        }
        
        // Search in expanding rings around the current position
        let maxSearchRadius = max(maxRows, columns)
        
        for radius in 1...maxSearchRadius {
            // Check positions at this radius
            for dx in -radius...radius {
                for dy in -radius...radius {
                    // Only check positions at the current radius (on the perimeter)
                    if abs(dx) != radius && abs(dy) != radius { continue }
                    
                    let newCol = currentPos.col + dx
                    let newRow = currentPos.row + dy
                    
                    // Check bounds
                    if newCol < 0 || newRow < 0 || 
                       newCol + buttonWidth > columns || 
                       newRow + buttonHeight > maxRows {
                        continue
                    }
                    
                    let candidateRect = GridRect(col: newCol, row: newRow, width: buttonWidth, height: buttonHeight)
                    
                    // Check if this position avoids the shadow and doesn't overlap with other buttons
                    if !rectsOverlap(candidateRect, draggedButtonShadow) && 
                       !hasOverlapExcluding(candidateRect, excluding: [button.id]) {
                        return GridPosition(col: newCol, row: newRow)
                    }
                }
            }
        }
        
        return nil // No available position found
    }

    // Check if a specific grid cell is occupied by any button (excluding currently dragged button)
    func isCellOccupied(col: Int, row: Int) -> Bool {
        // Only check buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        for button in pageButtons {
            // Skip the button that's currently being dragged
            if let draggedButton = dragging, draggedButton.id == button.id {
                continue
            }

            guard let buttonCol = button.gridCol, let buttonRow = button.gridRow else { continue }

            // Get button dimensions
            let buttonWidth = button.gridWidth
            let buttonHeight = button.gridHeight
            
            // Check if the cell (col, row) is within the button's area
            if col >= buttonCol && col < buttonCol + buttonWidth &&
               row >= buttonRow && row < buttonRow + buttonHeight {
                return true
            }
        }
        return false
    }

    // Count rows using a dynamic packing heuristic matching layout
    func occupiedRows(columns: Int) -> Int {
        // Only count rows for buttons on the current page
        let pageButtons = buttons.filter { $0.page == currentPage }
        guard !pageButtons.isEmpty else { return 1 }

        var occupancy: [[Bool]] = []
        func ensureRows(_ r: Int) {
            while occupancy.count <= r { occupancy.append(Array(repeating: false, count: columns)) }
        }

        func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
            ensureRows(r + h)
            if c + w > columns { return false }
            for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
            return true
        }

        func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) {
            ensureRows(r + h)
            for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } }
        }

        // First: place controls with explicit positions
        var explicitlyPlaced = Set<UUID>()
        for b in pageButtons {
            let w = b.gridWidth
            let h = b.gridHeight
            if let gridCol = b.gridCol, let gridRow = b.gridRow,
               gridCol >= 0, gridRow >= 0, fits(gridRow, gridCol, w, h) {
                mark(gridRow, gridCol, w, h)
                explicitlyPlaced.insert(b.id)
            }
        }
        
        // Then: place remaining controls with auto-packing
        for b in pageButtons where !explicitlyPlaced.contains(b.id) {
            let w = b.gridWidth
            let h = b.gridHeight
            var placed = false
            var r = 0
            while !placed {
                for c in 0..<columns {
                    if fits(r, c, w, h) {
                        mark(r, c, w, h)
                        placed = true
                        break
                    }
                }
                if !placed { r += 1 }
            }
        }
        
        var lastUsed = 0
        for (i, row) in occupancy.enumerated() { 
            if row.contains(true) { lastUsed = i + 1 } 
        }
        return max(1, lastUsed)
    }

    
    // Compute packed rows consistent with non-edit portrait packed layout
    func packedVisualRows() -> Int {
        let positions = computePackedPositions(for: buttons)
        var maxRow = 0
        for b in buttons {
            let pos = positions[b.id]
            let row = pos?.row ?? (b.gridRow ?? 0)
            let height = b.gridHeight
            maxRow = max(maxRow, row + height)
        }
        return max(1, maxRow)
    }

    
    // Helper function to build individual control tile (extracted from ForEach for type-checking performance)
    @ViewBuilder
    func buildControlTileView(button: ControlButton, cellSize: CGFloat, columnSpacing: CGFloat, rowSpacing: CGFloat, conflictFor: [MIDIKey: String], midiFilter: Set<Int>, isEditing: Bool, maxRows: Int, usbServer: ConnectionManager, wifiClient: BridgeOutput, connectionCoordinator: ConnectionCoordinator, controlButtons: Binding<[ControlButton]>, markDirty: @escaping () -> Void) -> some View {
        // Calculate button size
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let totalWidth = CGFloat(button.gridWidth) * cellSize + CGFloat(max(0, button.gridWidth - 1)) * columnSpacing
        let totalHeight = CGFloat(button.gridHeight) * cellSize + CGFloat(max(0, button.gridHeight - 1)) * rowSpacing
        // iPhone: buttons fill the full grid space (spacing creates gaps)
        let width = totalWidth
        let height = totalHeight

        let pos: (col: Int, row: Int) = effectivePosition(for: button, dragging: dragging, preview: previewLocation, columns: columns)
                // iPhone: no offset needed since buttons fill the full space
                let xBase = CGFloat(pos.col) * (cellSize + columnSpacing)
                let yBase = CGFloat(pos.row) * (cellSize + rowSpacing)
                let x = xBase
                let y = yBase

        // DEBUG: Log tile positioning for iPhone
        let _ = isPhone ? debugPrint("📱 [Tile] '\(button.title)' cellSize=\(cellSize), pos=(\(pos.col),\(pos.row)), offset=(\(x),\(y)), size=(\(width)x\(height))") : ()

        let key = MIDIKey(kind: button.kind, channel: button.channel, number: button.number)
                let owner = conflictFor[key]

                // Filter out the current button from conflict list
                let typePrefix = (button.isFader == true) ? "Fader" : "Button"
                let buttonDisplayName = button.title.isEmpty ? typePrefix : "\(typePrefix): \(button.title)"
                let filteredOwner: String? = {
                    var warning: String? = nil

                    // Check for MIDI conflicts
                    if let ownerString = owner {
                        // If owner string contains multiple owners (separated by "|||")
                        if ownerString.contains("|||") {
                            let owners = ownerString.split(separator: "|||")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { $0 != buttonDisplayName }
                            if !owners.isEmpty {
                                warning = owners.joined(separator: " and ")
                            }
                        } else {
                            // Single owner - check if it's this button
                            if ownerString.trimmingCharacters(in: .whitespaces) != buttonDisplayName {
                                warning = ownerString
                            }
                        }
                    }

                    // Check for filtered MIDI (only when filters are enabled)
                    if midiFiltersEnabled && !midiFilter.isEmpty && button.kind == .cc && midiFilter.contains(button.number) {
                        let filteredMsg = "Filtered CC"
                        if let existing = warning {
                            warning = "\(existing) • \(filteredMsg)"
                        } else {
                            warning = filteredMsg
                        }
                    }

                    return warning
                }()

                iPadControlTile(
                    button: button,
                    takenBy: filteredOwner,
                    isEditing: isEditing,
                    isDragging: dragging?.id == button.id,
                    defaultCueColor: defaultCueColor,
                    showMIDIData: showMIDIData,
                    onTap: { onTap(button) },
                    onEdit: {
                        // Look up the current button by ID to avoid stale closure captures after drag reorder
                        let current = controlButtons.wrappedValue.first(where: { $0.id == button.id }) ?? button
                        onEditButton(current)
                    },
                    onDelete: { onDelete(button) },
                    onDrag: {
                        // Keep the old system for compatibility, but we'll add smooth gesture on top
                        guard isEditing else { return NSItemProvider() }
                        return NSItemProvider(object: button.id.uuidString as NSString)
                    },
                    onFaderMIDI: { channel, cc, value, title, buttonID in
                        // Store the fader value in the ControlButton model for persistence
                        if let index = controlButtons.wrappedValue.firstIndex(where: { $0.id == buttonID }) {
                            let faderValue = Double(value) / 127.0
                            controlButtons.wrappedValue[index].faderValue = faderValue
                            markDirty() // Mark project as dirty to save the fader value
                            debugPrint("🎚️ onFaderMIDI: Stored fader value \(faderValue) for \"\(title)\"")
                        }

                        // Use ConnectionCoordinator to send MIDI through the active connection
                        connectionCoordinator.sendMIDI(type: .cc, channel: channel, number: cc, value: value, label: title, buttonID: buttonID.uuidString)
                    }
                )
                .id(button.id)
                .frame(width: width, height: height)
                .offset(
                    x: x + (dragging?.id == button.id ? dragTranslation.width : 0),
                    y: y + (dragging?.id == button.id ? dragTranslation.height : 0)
                )
                .scaleEffect((dragging?.id == button.id && !isPhone) ? 1.1 : 1.0) // iPad only: scale during drag
                // Enable smooth spring animations for buttons moving out of the way (iPhone-like)
                .animation(
                    dragging?.id == button.id ? nil : .spring(response: 0.35, dampingFraction: 0.75),
                    value: x
                )
                .animation(
                    dragging?.id == button.id ? nil : .spring(response: 0.35, dampingFraction: 0.75),
                    value: y
                )
                .animation(.easeInOut(duration: 0.15), value: dragging?.id == button.id) // Smooth scale animation
                .allowsHitTesting(true)
                .simultaneousGesture(
                    isEditing ?
                    DragGesture(minimumDistance: 10, coordinateSpace: .global)
                        .onChanged { value in
                            if dragging?.id != button.id {
                                // Start iOS-style drag
                                isDragOperation = true
                        dragging = button
                        dropSurfaceElevated = true
                                dragStartLocation = value.startLocation
                                previewLocation = nil
                            }
                            
                            if dragging?.id == button.id {
                                // Follow finger exactly - no constraints or modifications
                                let dx = value.translation.width
                                let dy = value.translation.height
                                
                                // Update dragged device position - this should follow finger exactly
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    dragTranslation = CGSize(width: dx, height: dy)
                                }
                                
                                // Calculate shadow position independently - this snaps to grid
                                let currentCol = button.gridCol ?? 0
                                let currentRow = button.gridRow ?? 0

                                let targetWidth = button.gridWidth
                                let targetHeight = button.gridHeight
                                
                                // Calculate target grid position based on drag distance
                                let cellsMovedX = Int((dx / (cellSize + columnSpacing)).rounded())
                                let cellsMovedY = Int((dy / (cellSize + rowSpacing)).rounded())
                                
                                // Calculate target position
                                let targetCol = currentCol + cellsMovedX
                                let targetRow = currentRow + cellsMovedY
                                
                                // Clamp to valid grid boundaries
                                let shadowCol = max(0, min(targetCol, columns - targetWidth))
                                let shadowRow = max(0, min(targetRow, maxRows - targetHeight))
                                
                                // Always update preview location for live displacement preview
                                // This allows other buttons to move out of the way in real-time
                                let newShadowPos = GridPosition(col: shadowCol, row: shadowRow)
                                if previewLocation?.col != shadowCol || previewLocation?.row != shadowRow {
                                    previewLocation = newShadowPos
                                }
                                
                                // Store shadow offset separately - this is for visual shadow positioning only
                                shadowOffset = CGSize(width: dx, height: dy)

                                // Check for edge drag to switch pages
                                let dragX = value.location.x
                                let gridWidth = actualWidth
                                checkEdgeDrag(dragX: dragX, gridWidth: gridWidth)
                            }
                        }
                        .onEnded { value in
                            guard dragging?.id == button.id else { return }

                            // Cancel any pending edge drag timer
                            cancelEdgeDragTimer()

                            // Snap to grid position like iOS home screen
                            if let preview = previewLocation {
                                // Commit the dragged button's position
                                if let buttonIndex = buttons.firstIndex(where: { $0.id == button.id }) {
                                    buttons[buttonIndex].gridCol = preview.col
                                    buttons[buttonIndex].gridRow = preview.row
                                    lastDropTime = Date()
                                    debugPrint("✅ Drop successful at (\(preview.col), \(preview.row))")
                                }
                                
                                // Commit positions for all displaced buttons
                                self.commitDisplacedButtonPositions(draggedButton: button, targetPosition: preview)
                            }
                            
                            // Clear drag state after drop is processed
                            clearDragState(reason: "iOS-style drag completed")
                        }
                    : nil
                )
                .zIndex(1)
            }

    // Helper function to compute packed positions (moved outside ViewBuilder)
    func computePackedPositions(for buttons: [ControlButton]) -> [UUID: (col: Int, row: Int)] {
        let isPortraitLike = verticalSizeClass != .compact
        guard !isEditing && isPortraitLike else { return [:] }
        
        var occupancy: [[Bool]] = []
        var packedPositions: [UUID: (col: Int, row: Int)] = [:]
        
        func ensureRows(_ r: Int) {
            while occupancy.count <= r { occupancy.append(Array(repeating: false, count: columns)) }
        }
        func fits(_ r: Int, _ c: Int, _ w: Int, _ h: Int) -> Bool {
            ensureRows(r + h)
            if c + w > columns { return false }
            for rr in r..<(r+h) { for cc in c..<(c+w) { if occupancy[rr][cc] { return false } } }
            return true
        }
        func mark(_ r: Int, _ c: Int, _ w: Int, _ h: Int) { for rr in r..<(r+h) { for cc in c..<(c+w) { occupancy[rr][cc] = true } } }
        
        for b in buttons {
            let w = b.gridWidth
            let h = b.gridHeight
            var placed = false
            var r = 0
            while !placed {
                ensureRows(r + h)
                for c in 0...(columns - w) {
                    if fits(r, c, w, h) {
                        mark(r, c, w, h)
                        packedPositions[b.id] = (c, r)
                        placed = true
                        break
                    }
                }
                if !placed { r += 1 }
            }
        }
        
        return packedPositions
    }

    
    // Helper to calculate grid parameters
    func calculateGridParameters(proxy: GeometryProxy) -> (cellSize: CGFloat, displayRows: Int, gridHeight: CGFloat, gridWidth: CGFloat) {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone

        var cellSize: CGFloat
        let displayRows: Int

        if isPhone {
            // iPhone: Use fixed cell size based on available height
            // This creates larger, easier-to-use controls that scroll horizontally
            // Always use 80% of landscape height (the shorter dimension) for consistency
            // Use cached value to avoid freeze from UIScreen.main.bounds access during layout
            let landscapeHeight = globalCachedPortraitWidth  // Already the shorter dimension
            let availableHeight = landscapeHeight * 0.8
            // Reserve space for header and grid padding
            let headerHeight: CGFloat = 68
            let gridVerticalPadding: CGFloat = 52  // 8pt top + 12pt bottom + scrollbar (28pt handle + 4pt bottom padding)
            let gridAreaHeight = availableHeight - headerHeight - gridVerticalPadding

            // Calculate cell size based on 4 rows (max) - NO MINIMUM, let it shrink to fit 80% height
            let maxRows = 4
            let verticalGaps = max(0, maxRows - 1)
            cellSize = floor((gridAreaHeight - CGFloat(verticalGaps) * rowSpacing) / CGFloat(maxRows))

            // iPhone: Dynamic rows like iPad - shrink to fit content, expand in edit mode
            if isEditing {
                displayRows = 4  // Full grid in edit mode
            } else {
                let visualRows = calculateVisualRows()
                displayRows = min(4, max(1, visualRows))  // At least 1 row, max 4
            }
        } else {
            // iPad: Calculate based on available width (original behavior)
            let totalSpacing = CGFloat(columns - 1) * columnSpacing
            let actualHorizontalPadding = gridPadding
            let availableWidth = proxy.size.width - (2 * actualHorizontalPadding) - totalSpacing
            cellSize = floor(availableWidth / CGFloat(columns))

            if isEditing {
                displayRows = 4
            } else {
                let visualRows = calculateVisualRows()
                displayRows = min(4, max(0, visualRows))
            }
        }

        let verticalGaps = max(0, displayRows - 1)
        let gridHeight = CGFloat(displayRows) * cellSize + CGFloat(verticalGaps) * rowSpacing
        let gridWidth = CGFloat(columns) * cellSize + CGFloat(max(0, columns - 1)) * columnSpacing

        return (cellSize: cellSize, displayRows: displayRows, gridHeight: gridHeight, gridWidth: gridWidth)
    }

    
    func buildControlGrid(proxy: GeometryProxy, isCtrlEditing: Bool, sessionNonce: Int, usbServer: ConnectionManager, wifiClient: BridgeOutput, connectionCoordinator: ConnectionCoordinator) -> AnyView {
        let params = calculateGridParameters(proxy: proxy)
        let cellSize = params.cellSize
        let displayRows = params.displayRows
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone // Moved up for debug
        // let dropTypes: [UTType] = isCtrlEditing ? [UTType.text] : [] // Unused in new iOS-style drag system

        let maxRows = displayRows // Capture for use in gesture closures
        let pageButtons = buttons.filter { $0.page == currentPage }

        let tilesCore = ForEach(pageButtons) { button in
            buildControlTileView(
                button: button,
                cellSize: cellSize,
                columnSpacing: columnSpacing,
                rowSpacing: rowSpacing,
                conflictFor: conflictFor,
                midiFilter: midiFilter,
                isEditing: isCtrlEditing,
                maxRows: maxRows,
                usbServer: usbServer,
                wifiClient: wifiClient,
                connectionCoordinator: connectionCoordinator,
                controlButtons: $buttons,
                markDirty: markDirty
            )
        }
        let tiles: AnyView = AnyView(
            Group { tilesCore }
                .id("tiles-\(isCtrlEditing)")
        )

        let editOverlay: AnyView = {
            guard isCtrlEditing else { return AnyView(EmptyView()) }
            let overlayCells: [(Int, Int)] = (0..<displayRows).flatMap { row in
                (0..<columns).compactMap { col in
                    isCellOccupied(col: col, row: row) ? nil : (row, col)
                }
            }
            let overlay = ForEach(overlayCells.indices, id: \.self) { idx in
                let (row, col) = overlayCells[idx]
                        let x = CGFloat(col) * (cellSize + columnSpacing)
                        let y = CGFloat(row) * (cellSize + rowSpacing)
                        RoundedRectangle(cornerRadius: CBRadius.small)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: cellSize, height: cellSize)
                            .offset(x: x, y: y)
                }
                .zIndex(0.5)
                .allowsHitTesting(false)
            return AnyView(overlay)
        }()

        let dragPreview: AnyView = {
            // iOS-style shadow: shows at TARGET grid position, not following finger
            guard let dragging = dragging, let preview = previewLocation else { return AnyView(EmptyView()) }
            let width = CGFloat(dragging.gridWidth) * cellSize + CGFloat(max(0, dragging.gridWidth - 1)) * columnSpacing
            let height = CGFloat(dragging.gridHeight) * cellSize + CGFloat(max(0, dragging.gridHeight - 1)) * rowSpacing
            
            // Simple shadow positioning - align exactly with grid cells
            let shadowX = CGFloat(preview.col) * (cellSize + columnSpacing)
            let shadowY = CGFloat(preview.row) * (cellSize + rowSpacing)
            
            // Choose shadow color based on whether displacement is valid
            let shadowColor = hasInvalidDisplacement ? Color.red : Color.blue

            // iPhone uses 6px corner radius, iPad uses 12px
            let cornerRadius: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 6 : 12

            let previewView = ZStack {
                // Shadow effect (blue if valid, red if no space available)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shadowColor.opacity(0.2))
                    .blur(radius: 8)
                    .scaleEffect(1.1)

                // Main preview shape
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shadowColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(shadowColor, lineWidth: 3)
                    )
            }
                    .frame(width: width, height: height)
            .offset(x: shadowX, y: shadowY)
            .zIndex(2000)
                    .allowsHitTesting(false)
            .animation(nil, value: preview.col) // No animations to prevent grid movement
            .animation(nil, value: preview.row) // No animations to prevent grid movement
            return AnyView(previewView)
        }()
        
        let _ = iPadDropDelegate( // Unused in new iOS-style drag system
            columns: columns,
            columnSpacing: columnSpacing,
            rowSpacing: rowSpacing,
            cellSize: cellSize,
            displayRows: displayRows,
            buttons: $buttons,
            dragging: $dragging,
            previewLocation: $previewLocation,
            dropSurfaceElevated: $dropSurfaceElevated,
            isDragOperation: $isDragOperation,
            lastDropTime: $lastDropTime,
            isActive: isCtrlEditing,
            clearDragState: clearDragState
        )

        let gridContent = ZStack(alignment: .topLeading) {
            // Controls positioned with simple offset (Mac editor approach)
            tiles
                .allowsHitTesting(true)

            // Dotted grid overlay in edit mode (Mac editor approach)
            editOverlay

            // Blue drag shadow preview
            dragPreview
        }
        .frame(
            width: params.gridWidth,
            height: params.gridHeight,
            alignment: .topLeading
        )

        // iPhone: Clipped grid with draggable scrollbar (no ScrollView to avoid gesture conflicts with faders)
        // iPad: No scroll needed, grid fits within screen
        let content: AnyView
        let totalContentWidth = params.gridWidth + 2 * columnSpacing
        if isPhone {
            content = AnyView(
                VStack(spacing: 0) {
                    // Clipped viewport — GeometryReader provides the clip bounds
                    GeometryReader { viewportGeo in
                        gridContent
                            .padding(.horizontal, columnSpacing)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                            .offset(x: -controlScrollOffset)
                            .onAppear {
                                controlVisibleWidth = viewportGeo.size.width
                            }
                            .onChange(of: viewportGeo.size.width) { _, newWidth in
                                controlVisibleWidth = newWidth
                            }
                    }
                    .clipped()

                    // Draggable scrollbar
                    ControlAreaScrollbar(
                        contentWidth: totalContentWidth,
                        visibleWidth: controlVisibleWidth,
                        scrollOffset: $controlScrollOffset
                    )
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .id("ctrl-container-\(isCtrlEditing)-sess-\(sessionNonce)-page-\(currentPage)-\(pageButtons.count)")
                .allowsHitTesting(true)
                .onChange(of: sessionNonce) { _, _ in
                    clearDragState(reason: "gesture cancelled")
                }
                .onChange(of: currentPage) { _, _ in
                    // Reset scroll when switching pages
                    controlScrollOffset = 0
                }
            )
        } else {
            content = AnyView(
                gridContent
                    .id("ctrl-container-\(isCtrlEditing)-sess-\(sessionNonce)-page-\(currentPage)-\(pageButtons.count)")
                    .padding(EdgeInsets(
                        top: isCtrlEditing ? 20 : 8,
                        leading: gridPadding,
                        bottom: gridPadding,
                        trailing: gridPadding
                    ))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .animation(.easeInOut(duration: 0.3), value: displayRows)
                    .allowsHitTesting(true)
                    .onChange(of: sessionNonce) { _, _ in
                        clearDragState(reason: "gesture cancelled")
                    }
            )
        }

        return content
}

struct ControlButtonTile: View {
    let button: ControlButton
    let takenBy: String?
    let isEditing: Bool
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State var down = false
    @State var wiggle = false

    // Wobble state - now uses shared animator
    @ObservedObject var wobbleAnimator = WobbleAnimator.shared
    @State var wobbleID = UUID()

    @Environment(\.colorScheme) var colorScheme
    @AppStorage("selectedThemeID") var selectedThemeID: String = "default"
    @AppStorage("customDefaultCueColor") var customDefaultCueColorStorage: String = ""

    var selectedTheme: AppTheme {
        AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
    }

    // iPhone/compact mode detection
    var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        let isToggle = button.isToggle ?? false

        // Determine if button should show as "on" (pressed/active)
        // iPad toggle buttons: only use toggleState (no flash on press)
        // Regular buttons or iPhone: use down state for press effect
        let isOn = (isToggle && !isPhone) ? button.toggleState : (isToggle ? button.toggleState : down)

        // Accent color (same for both modes)
        let accentColor: Color = {
            if let colorHex = button.colorHex {
                return Color(hex: colorHex)
            } else if !customDefaultCueColorStorage.isEmpty {
                return Color(hex: customDefaultCueColorStorage)
            } else {
                return selectedTheme.defaultCueColor(for: colorScheme)
            }
        }()

        // Filled tile background — always accent color
        let buttonColor: Color = isOn ? accentColor : accentColor.opacity(0.9)

        // Adaptive text color based on tile background brightness
        let textColor: Color = accentColor.needsDarkText() ? .black : .white

        ZStack {
            Button {
                    if isEditing { onEdit() } else { onTap() }
            } label: {
                VStack(spacing: 4) {
                        Spacer(minLength: 0)

                        if button.symbol.isEmpty {
                            // No icon: show title only
                            Text(button.title)
                                .font(.cb(points: isPhone ? 11 : 12, .bold))
                        } else if button.title.trimmingCharacters(in: .whitespaces).isEmpty {
                            // Icon-only mode: center the icon without title or MIDI label
                            Image(systemName: button.symbol)
                                .font(.cbIcon(.title, .semibold))
                                .foregroundColor(textColor)
                        } else {
                            // Icon + title mode: show all elements
                            Image(systemName: button.symbol)
                                .font(.cbIcon(.title, .semibold))
                                .foregroundColor(textColor)
                            Text(button.title)
                                .font(.cb(.caption, .bold))
                                .lineLimit(1)
                            Text(midiLabel())
                                .font(.cb(.micro))
                                .foregroundColor(textColor.opacity(0.5))
                        }

                        Spacer(minLength: 0)
                }
                .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: CBRadius.small)
                        .fill(buttonColor)
                )
                    .overlay(alignment: .topLeading) {
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
                        .contentShape(Rectangle())
                        .frame(width: isPhone ? 44 : 70, height: isPhone ? 44 : 70)
                            .offset(x: isPhone ? -10 : -32, y: isPhone ? -10 : -32)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(takenBy != nil && !isEditing)
            .opacity(1.0)
            .modifier(PressEffectWhenNotEditing(isEditing: isEditing, onChange: { down = true }, onEnd: { down = false }))
            .scaleEffect((down && !isEditing && !isPhone) ? 0.97 : 1.0)  // iPhone: no scale effect
            .animation(isPhone ? nil : .spring(response: 0.18, dampingFraction: 0.8), value: down)  // iPhone: no animation
            .modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
                .onChange(of: isEditing) { _, editing in
                    if editing { startWobble() } else { stopWobble(); down = false }
            }
            .onDisappear { stopWobble() }
        }
    }

    func midiLabel() -> String {
        switch button.kind {
        case .cc:   return "\(button.channel)•\(button.number)"
        case .note: return "\(button.channel)•\(button.number)•\(button.velocity)"
        }
    }

    // MARK: - iPhone-style wobble implementation (using shared animator)
    func startWobble() {
        guard isEditing else { return }

        var rng = SeededRandom(seed: button.id.uuidString.hashValue)
        let amplitude = 0.5 + Double(rng.nextNormalized()) * 0.3
        let scaleDelta = 0.001 + Double(rng.nextNormalized()) * 0.0005
        wobbleAnimator.startWobbling(for: wobbleID, amplitude: amplitude, scaleDelta: scaleDelta)
    }

    func stopWobble() {
        wobbleAnimator.stopWobbling(for: wobbleID)
    }

    // Helper: Calculate relative luminance of a color
    func relativeLuminance(hex: String) -> Double {
        let rgb = hexToRGB(hex)
        func adjust(_ c: Double) -> Double {
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = adjust(Double(rgb.0) / 255.0)
        let g = adjust(Double(rgb.1) / 255.0)
        let b = adjust(Double(rgb.2) / 255.0)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    // Helper: Convert hex to RGB
    func hexToRGB(_ hex: String) -> (Int, Int, Int) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r = Int((int >> 16) & 0xFF)
        let g = Int((int >> 8) & 0xFF)
        let b = Int(int & 0xFF)
        return (r, g, b)
    }
}

    
    // Edit grid overlay made of dotted squares the size of half a button
    struct CBGridOverlay: View {
        let columns: Int
        let rows: Int
        let columnSpacing: CGFloat = 12
        let rowSpacing: CGFloat = 10
        
        var body: some View {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let colCount = max(1, columns)
                let rowCount = max(1, rows)
                let totalColSpacing = columnSpacing * CGFloat(max(0, colCount - 1))
                // Base cells: each base cell is one column. Button spans 2 base cells (rectangular).
                let cellWidth = (totalWidth - totalColSpacing) / CGFloat(colCount)
                let cellHeight = cellWidth // squares
                let dashed = StrokeStyle(lineWidth: 1, dash: [4, 4])
                let color = Color.secondary.opacity(0.5)
                ZStack {
                    ForEach(0..<rowCount, id: \.self) { r in
                        ForEach(0..<colCount, id: \.self) { c in
                            let x = CGFloat(c) * (cellWidth + columnSpacing)
                            let y = CGFloat(r) * (cellHeight + rowSpacing)
                            let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                            RoundedRectangle(cornerRadius: CBRadius.control)
                                .inset(by: 4)
                                .stroke(style: dashed)
                                .foregroundColor(color)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
            }
        }
    }

    
    // (moved earlier above CBControlSection)

    // SNAKE: Fader control tile (two rows tall, half width)
    struct ControlFaderTile: View {
        let button: ControlButton
        let takenBy: String?
        let isEditing: Bool
        var onTap: () -> Void
        var onEdit: () -> Void
        var onDelete: () -> Void

        // 0.0..1.0 mapped to CC 0..127, rest at 84
        @State var value: Double = Double(84) / 127.0
        @State var wiggle = false

        // Wobble state - now uses shared animator
        @ObservedObject var wobbleAnimator = WobbleAnimator.shared
        @State var wobbleID = UUID()

        @Environment(\.colorScheme) var colorScheme
        @AppStorage("selectedThemeID") var selectedThemeID: String = "default"
        @AppStorage("customDefaultCueColor") var customDefaultCueColorStorage: String = ""

        var selectedTheme: AppTheme {
            AppTheme.allThemes.first { $0.id == selectedThemeID } ?? AppTheme.defaultTheme
        }

        // iPhone/compact mode detection
        var isPhone: Bool {
            UIDevice.current.userInterfaceIdiom == .phone
        }

        var body: some View {
            let isHorizontal = (button.faderOrientation == "horizontal")
            let direction = button.faderDirection ?? (isHorizontal ? "right" : "up")

            // Use custom color if button has colorHex, otherwise use custom accent color if set, otherwise use theme default
            let faderColor: Color = {
                if let colorHex = button.colorHex {
                    return Color(hex: colorHex)
                } else if !customDefaultCueColorStorage.isEmpty {
                    return Color(hex: customDefaultCueColorStorage)
                } else {
                    return selectedTheme.defaultCueColor(for: colorScheme)
                }
            }()
            ZStack(alignment: .topTrailing) {
                // Fill entire available space - 1x2 for vertical, 2x1 for horizontal
                GeometryReader { geo in
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
                                .fill(faderColor.opacity(0.2))

                            // Fader fill (dynamic based on value) - alignment handles the direction
                            RoundedRectangle(cornerRadius: CBRadius.small)
                                .fill(faderColor.opacity(0.85))
                                .frame(width: w * value)
                                .padding(3)

                            // Fader head (dynamic position) - conditional offset for direction
                            RoundedRectangle(cornerRadius: CBRadius.small)
                                .fill(faderColor)
                                .frame(width: headWidth)
                                .offset(x: (direction == "right") ? (w * value) : -(w * value))
                                .padding(.vertical, 6)

                            // Text overlay inside fader at left
                            // Adaptive text color: switches based on whether fader fill covers the text
                            // Text is left-aligned, so for "right" direction fill covers it early, for "left" late
                            HStack(spacing: 2) {
                                let filledTextColor: Color = faderColor.needsDarkText() ? .black : .white
                                let emptyTextColor: Color = .white  // Dark mode background
                                let textOnFill = (direction == "right") ? value > 0.1 : value > 0.85
                                let faderTextColor = textOnFill ? filledTextColor : emptyTextColor
                                Text(button.title)
                                    .font(.cb(.caption, .bold))
                                    .lineLimit(1)
                                    .foregroundColor(faderTextColor)
                                    .minimumScaleFactor(0.7)
                                Text("CC\(button.number)")
                                    .font(.cb(.micro))
                                    .foregroundColor(faderTextColor.opacity(0.5))
                                Text("Ch\(button.channel)")
                                    .font(.cb(.micro))
                                    .foregroundColor(faderTextColor.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)

                            // Full-track gesture: tap/drag anywhere
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { g in
                                            guard !isEditing else { return }
                                            let localX = g.location.x
                                            let clamped = max(headWidth / 2, min(w - headWidth / 2, localX))
                                            var normalized = Double((clamped - headWidth / 2) / (w - headWidth))
                                            // Reverse input if direction is "left"
                                            if shouldReverse {
                                                normalized = 1.0 - normalized
                                            }
                                            value = max(0, min(1, normalized))
                                            sendCC()
                                        }
                                        .onEnded { _ in if !isEditing { sendCC() } }
                                )
                        }
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
                                .fill(faderColor.opacity(0.2))

                            // Fader fill (dynamic based on value) - alignment handles the direction
                            RoundedRectangle(cornerRadius: CBRadius.small)
                                .fill(faderColor.opacity(0.85))
                                .frame(height: h * value)
                                .padding(3)

                            // Fader head (dynamic position) - conditional offset for direction
                            RoundedRectangle(cornerRadius: CBRadius.small)
                                .fill(faderColor)
                                .frame(height: headHeight)
                                .offset(y: (direction == "up") ? -(h * value) : (h * value))
                                .padding(.horizontal, 6)

                            // Text overlay inside fader at top
                            // Adaptive text color: for "up" direction title at top needs high fill, for "down" title covered early
                            VStack(spacing: 2) {
                                let filledTextColor: Color = faderColor.needsDarkText() ? .black : .white
                                let emptyTextColor: Color = .white  // Dark mode background
                                let titleOnFill = (direction == "up") ? value > 0.75 : value > 0.15
                                let midiOnFill = (direction == "up") ? value > 0.15 : value > 0.75
                                Text(button.title)
                                    .font(.cb(.caption, .bold))
                                    .lineLimit(1)
                                    .foregroundColor(titleOnFill ? filledTextColor : emptyTextColor)
                                    .minimumScaleFactor(0.7)
                                Text("CC\(button.number)")
                                    .font(.cb(.micro))
                                    .foregroundColor((midiOnFill ? filledTextColor : emptyTextColor).opacity(0.5))
                                Text("Ch\(button.channel)")
                                    .font(.cb(.micro))
                                    .foregroundColor((midiOnFill ? filledTextColor : emptyTextColor).opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 6)
                            .allowsHitTesting(false)

                            // Full-track gesture: tap/drag anywhere
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { g in
                                            guard !isEditing else { return }
                                            let localY = g.location.y
                                            let clamped = max(headHeight / 2, min(h - headHeight / 2, h - localY))
                                            var normalized = Double((clamped - headHeight / 2) / (h - headHeight))
                                            // Reverse input if direction is "down"
                                            if shouldReverse {
                                                normalized = 1.0 - normalized
                                            }
                                            value = max(0, min(1, normalized))
                                            sendCC()
                                        }
                                        .onEnded { _ in if !isEditing { sendCC() } }
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // FIX: Removed padding to make faders fill grid cells like buttons
                .background(
                    RoundedRectangle(cornerRadius: CBRadius.card)
                        .fill(Color.clear)
                )
                if isEditing {
                    Button(action: onDelete) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.9))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.cbIcon(.small, .bold))
                                .foregroundColor(Color(uiColor: .systemBackground))
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .frame(width: 70, height: 70)
                    .offset(x: -32, y: -32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .opacity(1.0)
            .disabled(takenBy != nil && !isEditing)
            // FIX: Removed .onTapGesture to eliminate delay - edit by tapping delete button instead
            // The onTapGesture was causing ~300ms delay because SwiftUI waits to disambiguate tap vs drag
            .modifier(TimeBasedWobbleModifier(wobbleID: wobbleID, wobbleAnimator: wobbleAnimator))
            .onChange(of: isEditing) { _, editing in
                if editing { startWobble() } else { stopWobble() }
            }
            .onAppear {
                // Initialize fader value from stored value in ControlButton model
                if let storedValue = button.faderValue {
                    value = storedValue
                    debugPrint("🎚️ ControlFaderTile: Initialized fader \"\(button.title)\" with stored value: \(storedValue)")
                } else {
                    // Use default value for new faders
                    let defaultValue = Double(84) / 127.0
                    value = defaultValue
                    debugPrint("🎚️ ControlFaderTile: Initialized fader \"\(button.title)\" with default value: \(defaultValue)")
                }

                if isEditing { startWobble() }
            }
            .onDisappear {
                stopWobble()
            }
        }
        
        // MARK: - iPhone-style wobble implementation (using shared animator)
        func startWobble() {
            guard isEditing else { return }

            var rng = SeededRandom(seed: button.id.uuidString.hashValue)
            let amplitude = 0.5 + Double(rng.nextNormalized()) * 0.3
            let scaleDelta = 0.001 + Double(rng.nextNormalized()) * 0.0005
            wobbleAnimator.startWobbling(for: wobbleID, amplitude: amplitude, scaleDelta: scaleDelta)
        }

        func stopWobble() {
            wobbleAnimator.stopWobbling(for: wobbleID)
        }
        
        func sendCC() {
            let intVal = Int(round(value * 127))
            // Simple post via Notification; parent view already routes via triggerControl for buttons.
            // For faders, emit a custom notification so parent can listen and forward.
            NotificationCenter.default.post(name: Notification.Name("cbFaderChanged"),
                                            object: nil,
                                            userInfo: ["id": button.id, "channel": button.channel, "cc": button.number, "value": intVal, "title": button.title])
        }

        // Helper: Calculate relative luminance of a color
        func relativeLuminance(hex: String) -> Double {
            let rgb = hexToRGB(hex)
            func adjust(_ c: Double) -> Double {
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            let r = adjust(Double(rgb.0) / 255.0)
            let g = adjust(Double(rgb.1) / 255.0)
            let b = adjust(Double(rgb.2) / 255.0)
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        }

        // Helper: Convert hex to RGB
        func hexToRGB(_ hex: String) -> (Int, Int, Int) {
            let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int = UInt64()
            Scanner(string: hex).scanHexInt64(&int)
            let r = Int((int >> 16) & 0xFF)
            let g = Int((int >> 8) & 0xFF)
            let b = Int(int & 0xFF)
            return (r, g, b)
        }
    }
}
