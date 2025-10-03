# UI/UX Review Checklist for Cue Bear

Use this checklist before completing ANY UI change to ensure quality and prevent common issues.

---

## Pre-Implementation

### Design Considerations
- [ ] Understand the full context of the UI change
- [ ] Consider impact on existing user workflows
- [ ] Verify the change matches iOS design guidelines
- [ ] Check if similar patterns exist elsewhere in the app

### Planning
- [ ] Identify all affected views and components
- [ ] Plan for different device sizes (iPad 11", 12.9", iPad mini)
- [ ] Consider portrait AND landscape orientations
- [ ] Think about Dynamic Type scaling

---

## During Implementation

### Layout
- [ ] Use `.fixedSize()` on Text that should never wrap
- [ ] Use `minWidth` instead of fixed `width` for flexibility
- [ ] Add `.lineLimit(1)` as backup for single-line labels
- [ ] Ensure adequate spacing between elements
- [ ] Use Spacer() appropriately, not fixed heights

### Text & Typography
- [ ] Test with longest expected text strings
- [ ] Verify text doesn't truncate unexpectedly
- [ ] Check text contrast ratios (accessibility)
- [ ] Use semantic font styles (.headline, .body, .caption)
- [ ] Avoid hardcoded font sizes

### Colors & Styling
- [ ] Use semantic colors (.primary, .secondary, .accentColor)
- [ ] Ensure sufficient contrast for readability
- [ ] Test in both Light and Dark mode
- [ ] Use opacity for disabled states, not gray colors

### Touch Targets
- [ ] All interactive elements minimum 44x44 points
- [ ] Add `.contentShape(Rectangle())` for full tap area
- [ ] Ensure buttons have clear pressed states
- [ ] Verify gestures don't conflict with each other

---

## Testing Checklist

### Device Size Testing
- [ ] Test on iPad 11" (simulator or physical)
- [ ] Test on iPad 12.9" (simulator or physical)
- [ ] Test on iPad mini if users might use it
- [ ] Verify no layout breaking at any size

### Orientation Testing
- [ ] Test in portrait orientation
- [ ] Test in landscape orientation
- [ ] Verify transitions between orientations are smooth
- [ ] Check that no content is cut off in either orientation

### Dynamic Type Testing
- [ ] Open Settings > Accessibility > Display & Text Size
- [ ] Test with smallest text size
- [ ] Test with largest text size
- [ ] Test with largest accessibility size
- [ ] Verify text doesn't wrap or overflow unexpectedly
- [ ] Ensure all text remains readable

### Interaction Testing
- [ ] Tap all interactive elements to verify they work
- [ ] Test long press gestures if applicable
- [ ] Test swipe gestures if applicable
- [ ] Verify keyboard appears/dismisses correctly
- [ ] Test with VoiceOver enabled (basic check)

### Edge Cases
- [ ] Test with empty states (no data)
- [ ] Test with maximum data (long lists, many items)
- [ ] Test with very long text in fields
- [ ] Test with special characters and emojis
- [ ] Test rapid tapping/interaction (no crashes)

---

## Performance Check

### Rendering
- [ ] UI updates smoothly (60 fps)
- [ ] No janky scrolling or animations
- [ ] Images load without stuttering
- [ ] List rendering is performant

### Memory
- [ ] No memory leaks from view updates
- [ ] No retain cycles in closures
- [ ] Proper cleanup in `.onDisappear`

---

## Accessibility

### Basic Accessibility
- [ ] All interactive elements have `.accessibilityLabel()`
- [ ] Buttons describe their action
- [ ] Images have `.accessibilityLabel()` if meaningful
- [ ] Decorative images use `.accessibilityHidden(true)`

### VoiceOver Testing (Optional but Recommended)
- [ ] Enable VoiceOver in Settings > Accessibility
- [ ] Navigate through the changed UI
- [ ] Verify all elements are announced correctly
- [ ] Ensure logical navigation order

---

## Final Review

### Code Quality
- [ ] No force unwraps (`!`) in UI code
- [ ] No hardcoded magic numbers
- [ ] Proper use of state management
- [ ] Comments explain complex layout logic
- [ ] Consistent indentation and formatting

### User Experience
- [ ] Change feels intuitive and natural
- [ ] No confusing labels or instructions
- [ ] Error states are clear and helpful
- [ ] Success states provide feedback
- [ ] Loading states show progress

### Documentation
- [ ] Complex UI patterns are documented
- [ ] Non-obvious behavior is explained in comments
- [ ] Any workarounds are documented with reasons

---

## Common Issues to Watch For

### Text Wrapping Issues
- ❌ **Problem:** Fixed width frame on variable-length text
- ✅ **Solution:** Use `.fixedSize()` + `minWidth`

### Layout Breaking
- ❌ **Problem:** UI breaks at certain text sizes or device orientations
- ✅ **Solution:** Test thoroughly across sizes before committing

### Accessibility Gaps
- ❌ **Problem:** Buttons without labels, images without descriptions
- ✅ **Solution:** Add `.accessibilityLabel()` to all interactive elements

### Performance Issues
- ❌ **Problem:** UI stutters or lags during interaction
- ✅ **Solution:** Profile with Instruments, optimize expensive operations

### Dark Mode Oversight
- ❌ **Problem:** Hardcoded colors look wrong in dark mode
- ✅ **Solution:** Use semantic colors that adapt automatically

---

## Sign-Off

Before marking a UI task as complete:

1. ✅ All checklist items above are verified
2. ✅ Screenshots/screen recording provided (if major change)
3. ✅ User has tested on their device (if possible)
4. ✅ No regressions in other parts of the UI
5. ✅ Changes are committed with clear description

**Agent Name:** ____________________
**Date:** ____________________
**UI Change Description:** ____________________

---

## Quick Reference: SwiftUI Best Practices

```swift
// ✅ GOOD: Flexible text that won't wrap
Text("MIDI Channel")
    .fixedSize()
    .frame(minWidth: 110, alignment: .leading)

// ❌ BAD: Fixed width may cause wrapping
Text("MIDI Channel")
    .frame(width: 100, alignment: .leading)

// ✅ GOOD: Semantic colors
.foregroundColor(.primary)
.background(.secondary)

// ❌ BAD: Hardcoded colors
.foregroundColor(.black)
.background(.white)

// ✅ GOOD: Full tap target
Button("Delete") { }
    .contentShape(Rectangle())
    .frame(minHeight: 44)

// ❌ BAD: Small, hard to tap
Button("Delete") { }
    .frame(height: 20)

// ✅ GOOD: Accessibility
Image(systemName: "trash")
    .accessibilityLabel("Delete item")

// ❌ BAD: No accessibility
Image(systemName: "trash")
```

---

**Remember:** UI issues caught during review are 10x cheaper to fix than issues caught by users in production!