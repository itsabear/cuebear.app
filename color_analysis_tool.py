#!/usr/bin/env python3
"""
Color Analysis Tool for Cue Bear Themes
Analyzes contrast ratios, accessibility, and provides optimization recommendations
"""

import colorsys
import math

def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple (0-255)"""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    """Convert RGB (0-255) to hex"""
    return f"{int(r):02X}{int(g):02X}{int(b):02X}"

def relative_luminance(r, g, b):
    """Calculate relative luminance for WCAG contrast"""
    def adjust(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * adjust(r) + 0.7152 * adjust(g) + 0.0722 * adjust(b)

def contrast_ratio(color1_hex, color2_hex):
    """Calculate WCAG contrast ratio between two colors"""
    r1, g1, b1 = hex_to_rgb(color1_hex)
    r2, g2, b2 = hex_to_rgb(color2_hex)

    l1 = relative_luminance(r1, g1, b1)
    l2 = relative_luminance(r2, g2, b2)

    lighter = max(l1, l2)
    darker = min(l1, l2)

    return (lighter + 0.05) / (darker + 0.05)

def wcag_rating(ratio):
    """Get WCAG rating for contrast ratio"""
    if ratio >= 7.0:
        return "AAA (Enhanced) - Excellent!"
    elif ratio >= 4.5:
        return "AA (Normal) - Good"
    elif ratio >= 3.0:
        return "AA Large Text - Acceptable for large text only"
    else:
        return "FAIL - Insufficient contrast"

def adjust_lightness(hex_color, factor):
    """Adjust lightness of color. factor > 1 = lighter, < 1 = darker"""
    r, g, b = hex_to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r/255, g/255, b/255)
    l = min(1.0, max(0.0, l * factor))
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return rgb_to_hex(r*255, g*255, b*255)

def suggest_optimized_color(foreground_hex, background_hex, target_ratio=4.5):
    """Suggest an optimized foreground color for better contrast"""
    current_ratio = contrast_ratio(foreground_hex, background_hex)

    if current_ratio >= target_ratio:
        return foreground_hex, current_ratio, "Already meets target"

    # Try darkening or lightening
    best_color = foreground_hex
    best_ratio = current_ratio

    for factor in [0.5, 0.6, 0.7, 0.8, 1.2, 1.3, 1.4, 1.5]:
        adjusted = adjust_lightness(foreground_hex, factor)
        ratio = contrast_ratio(adjusted, background_hex)
        if ratio > best_ratio:
            best_ratio = ratio
            best_color = adjusted

    return best_color, best_ratio, "Adjusted" if best_color != foreground_hex else "No improvement"

def analyze_theme(theme_name, light_colors, dark_colors):
    """Analyze a theme's color accessibility"""
    print(f"\n{'='*80}")
    print(f"THEME: {theme_name}")
    print(f"{'='*80}\n")

    # Analyze light mode
    print("LIGHT MODE ANALYSIS")
    print("-" * 80)

    bg = light_colors['background']
    accent = light_colors['accent']
    cue = light_colors['defaultCue']

    print(f"Background: #{bg}")
    print(f"Accent: #{accent}")
    print(f"Default Cue: #{cue}\n")

    # Contrast checks
    accent_contrast = contrast_ratio(accent, bg)
    cue_contrast = contrast_ratio(cue, bg)

    print(f"Accent vs Background: {accent_contrast:.2f}:1 - {wcag_rating(accent_contrast)}")
    print(f"Cue vs Background: {cue_contrast:.2f}:1 - {wcag_rating(cue_contrast)}")

    # Suggestions for light mode
    if accent_contrast < 4.5:
        optimized, new_ratio, status = suggest_optimized_color(accent, bg, 4.5)
        print(f"\n⚠️  RECOMMENDATION: Accent color needs more contrast")
        print(f"   Current: #{accent} ({accent_contrast:.2f}:1)")
        print(f"   Suggested: #{optimized} ({new_ratio:.2f}:1)")
    else:
        print(f"\n✅ Accent color meets WCAG AA standards")

    if cue_contrast < 4.5:
        optimized, new_ratio, status = suggest_optimized_color(cue, bg, 4.5)
        print(f"\n⚠️  RECOMMENDATION: Cue color needs more contrast")
        print(f"   Current: #{cue} ({cue_contrast:.2f}:1)")
        print(f"   Suggested: #{optimized} ({new_ratio:.2f}:1)")
    else:
        print(f"✅ Cue color meets WCAG AA standards")

    # Analyze dark mode
    print(f"\n\nDARK MODE ANALYSIS")
    print("-" * 80)

    dark_bg = dark_colors['background']
    dark_accent = dark_colors['accent']
    dark_cue = dark_colors['defaultCue']

    print(f"Background: #{dark_bg}")
    print(f"Accent: #{dark_accent}")
    print(f"Default Cue: #{dark_cue}\n")

    dark_accent_contrast = contrast_ratio(dark_accent, dark_bg)
    dark_cue_contrast = contrast_ratio(dark_cue, dark_bg)

    print(f"Accent vs Background: {dark_accent_contrast:.2f}:1 - {wcag_rating(dark_accent_contrast)}")
    print(f"Cue vs Background: {dark_cue_contrast:.2f}:1 - {wcag_rating(dark_cue_contrast)}")

    if dark_accent_contrast < 4.5:
        optimized, new_ratio, status = suggest_optimized_color(dark_accent, dark_bg, 4.5)
        print(f"\n⚠️  RECOMMENDATION: Accent color needs more contrast")
        print(f"   Current: #{dark_accent} ({dark_accent_contrast:.2f}:1)")
        print(f"   Suggested: #{optimized} ({new_ratio:.2f}:1)")
    else:
        print(f"\n✅ Accent color meets WCAG AA standards")

    if dark_cue_contrast < 4.5:
        optimized, new_ratio, status = suggest_optimized_color(dark_cue, dark_bg, 4.5)
        print(f"\n⚠️  RECOMMENDATION: Cue color needs more contrast")
        print(f"   Current: #{dark_cue} ({dark_cue_contrast:.2f}:1)")
        print(f"   Suggested: #{optimized} ({new_ratio:.2f}:1)")
    else:
        print(f"✅ Cue color meets WCAG AA standards")

# Define all themes from AppTheme.swift
themes = {
    "Classic (Default)": {
        "light": {"background": "F2F2F7", "accent": "007AFF", "defaultCue": "0A84FF"},
        "dark": {"background": "000000", "accent": "0A84FF", "defaultCue": "0A84FF"}
    },
    "Neon Glow (Pop)": {
        "light": {"background": "FFE5F0", "accent": "FF3399", "defaultCue": "FF66B2"},
        "dark": {"background": "1A0A14", "accent": "FF3399", "defaultCue": "FF66B2"}
    },
    "Golden Hour (Hip-Hop)": {
        "light": {"background": "FFF9E6", "accent": "D9B327", "defaultCue": "FFD93D"},
        "dark": {"background": "1A1508", "accent": "D9B327", "defaultCue": "FFD93D"}
    },
    "Amp Red (Rock)": {
        "light": {"background": "FFE5E5", "accent": "CC1A1A", "defaultCue": "FF3333"},
        "dark": {"background": "1A0505", "accent": "CC1A1A", "defaultCue": "FF3333"}
    },
    "Cyber Cyan (Electronic)": {
        "light": {"background": "E6F7FF", "accent": "00CCFF", "defaultCue": "33E0FF"},
        "dark": {"background": "001A1F", "accent": "00CCFF", "defaultCue": "33E0FF"}
    },
    "Velvet Soul (R&B)": {
        "light": {"background": "F3E6FF", "accent": "8C4DB3", "defaultCue": "B366E0"},
        "dark": {"background": "120A16", "accent": "8C4DB3", "defaultCue": "B366E0"}
    },
    "Barn Sunset (Country)": {
        "light": {"background": "FFF5E6", "accent": "BF8C4D", "defaultCue": "E6A85C"},
        "dark": {"background": "1A120A", "accent": "BF8C4D", "defaultCue": "E6A85C"}
    },
    "Sunset Rhythm (Latin)": {
        "light": {"background": "FFF0E6", "accent": "FF6600", "defaultCue": "FF8533"},
        "dark": {"background": "1F0F00", "accent": "FF6600", "defaultCue": "FF8533"}
    },
    "Hallyu Pink (K-Pop)": {
        "light": {"background": "FFEBF7", "accent": "F266CC", "defaultCue": "FF85E0"},
        "dark": {"background": "1F0A1A", "accent": "F266CC", "defaultCue": "FF85E0"}
    },
    "Bourbon Smoke (Jazz)": {
        "light": {"background": "FFE6EB", "accent": "991F33", "defaultCue": "CC3D5C"},
        "dark": {"background": "14050A", "accent": "991F33", "defaultCue": "CC3D5C"}
    },
    "Lo-Fi Teal (Indie)": {
        "light": {"background": "E6F7F2", "accent": "33A88C", "defaultCue": "52D9B8"},
        "dark": {"background": "0A1512", "accent": "33A88C", "defaultCue": "52D9B8"}
    }
}

# Analyze all themes
for theme_name, colors in themes.items():
    analyze_theme(theme_name, colors['light'], colors['dark'])

print(f"\n{'='*80}")
print("ANALYSIS COMPLETE")
print(f"{'='*80}\n")
print("KEY STANDARDS:")
print("• AAA (7:1) - Best for accessibility, recommended for live performance")
print("• AA (4.5:1) - Minimum for normal text")
print("• AA Large (3:1) - Minimum for text > 18pt or 14pt bold")
print("\nFor live performance use (stage lighting, etc), aim for AAA standards.")
