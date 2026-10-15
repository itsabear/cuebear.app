//
//  ControlArea+Pages.swift — Cue Bear
//  CBControlSection: Page Navigation
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Combine

extension CBControlSection {
    /// Returns buttons on the current page only
    var currentPageButtons: [ControlButton] {
        buttons.filter { $0.page == currentPage }
    }

    /// Returns pages that have at least one control (for non-edit mode navigation)
    var pagesWithControls: [Int] {
        let usedPages = Set(buttons.map { $0.page })
        return (0..<totalPages).filter { usedPages.contains($0) }.sorted()
    }

    /// In edit mode: show all pages. Otherwise: only pages with controls
    var availablePages: [Int] {
        if isEditing {
            return Array(0..<totalPages)
        } else {
            let pages = pagesWithControls
            // If no controls at all, still show page 0
            return pages.isEmpty ? [0] : pages
        }
    }

    /// Previous available page (skipping empty pages in non-edit mode)
    var previousPage: Int? {
        let pages = availablePages
        guard let currentIndex = pages.firstIndex(of: currentPage), currentIndex > 0 else {
            return nil
        }
        return pages[currentIndex - 1]
    }

    /// Next available page (skipping empty pages in non-edit mode)
    var nextPage: Int? {
        let pages = availablePages
        guard let currentIndex = pages.firstIndex(of: currentPage), currentIndex < pages.count - 1 else {
            return nil
        }
        return pages[currentIndex + 1]
    }

    /// Display string for page indicator (e.g., "1/4" in edit mode, "1/2" if only 2 pages have controls)
    var pageIndicatorText: String {
        let pages = availablePages
        let displayPage = (pages.firstIndex(of: currentPage) ?? 0) + 1
        return "\(displayPage)/\(pages.count)"
    }
}
