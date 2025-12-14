# UI/UX Design Guidelines for Feature Pages

This document outlines the design implementation, color palette, typography, and component structures used to generate feature pages for Hadaa. Use this guide to automatically generate new pages that conform to the existing aesthetic.

## 1. Core Aesthetics & Theme

**Theme Name:** Premium Dark / Nature Tech
**Design Philosophy:** Sleek, modern, and immersive. Uses deep dark backgrounds to make vibrant accent colors and imagery pop. Emphasizes "Local Intelligence" and "Sustainable Success" through visually rich gradients and high-quality background imagery (often generated).

### Color Palette

| Name | Hex Code | Purpose |
| :--- | :--- | :--- |
| **Primary** | `#5c6bc0` | Brand primary (soft indigo) |
| **Secondary** | `#f23faf` | Brand secondary (vibrant pink) - often used in gradients |
| **Accent** | `#00acc1` | Core accent (cyan/teal) - used for calls-to-action, active states, and highlights |
| **Neutral-900** | `#212121` | Main background color (deep grey/almost black) |
| **Neutral-800** | `#424242` | Card/Section background (lighter grey) |
| **Text-Light** | `#f8f8f8` | Primary text color on dark backgrounds |
| **Text-Dark** | `#212121` | Primary text color on light backgrounds |
| **Gradient** | `from-accent to-secondary` | Used for text clips, buttons, and section backgrounds |

### Typography

-   **Primary Font:** `Roboto` (Sans-serif) - Used for body text and UI elements.
-   **Display/Fancy Font:** `Comic Relief` (System UI fallback) - *Note: Though defined in CSS, feature pages primarily use the Sans font stack (`font-sans`) for a clean look.*
-   **Headings:** Bold to Extra Bold weight (`font-extrabold`).
-   **Body:** Light to Normal weight (`font-light` to `font-normal`).

---

## 2. Page Structure & Layout

All feature pages should follow this standard section hierarchy. The entire page content is wrapped in a container that defines the base theme.

**Root Wrapper:**
```html
<div class="bg-neutral-900 text-white min-h-screen font-sans selection:bg-accent selection:text-black">
  <!-- Sections go here -->
</div>
```

### A. Hero Section
Immersive, full-screen feel with background image and gradient overlay.

*   **Wrapper:** `<section class="relative py-20 lg:py-32 overflow-hidden">`
*   **Background:**
    1.  Gradient Overlay: `absolute inset-0 bg-gradient-to-b from-black/80 via-neutral-900/90 to-neutral-900 z-0`
    2.  Image: `absolute inset-0 bg-cover bg-center opacity-20` (use `asset_path`)
*   **Content:** Centered (`text-center`) with `relative z-10`.
*   **Components:**
    1.  **Tag:** `inline-block py-1 px-3 rounded-full bg-accent/10 border border-accent/30 text-accent text-sm font-bold tracking-wider mb-6 animate-fade-in-up`
    2.  **H1 Title:** `text-5xl md:text-7xl font-extrabold tracking-tight mb-8 leading-tight animate-fade-in-up delay-100`
        *   *Highlight:* Use `<span class="text-transparent bg-clip-text bg-gradient-to-r from-accent to-secondary">` for key phrases.
    3.  **Subtitle:** `text-xl md:text-2xl text-neutral-300 max-w-4xl mx-auto leading-relaxed mb-12 animate-fade-in-up delay-200 font-light`
    4.  **Buttons:** Flex container (`flex flex-col sm:flex-row justify-center gap-4`). see [Components](#3-components).

### B. Feature Grid / Intro Section
Dark section with glass-morphism cards explaining "Why".

*   **Wrapper:** `<section class="py-16 bg-neutral-900">`
*   **Card Container:** `bg-neutral-800/50 rounded-3xl p-8 md:p-12 border border-white/5 shadow-2xl backdrop-blur-sm relative overflow-hidden`
*   **Grid:** `grid grid-cols-1 md:grid-cols-3 gap-8`
*   **Feature Item:**
    *   **Icon:** `w-12 h-12 rounded-2xl bg-accent/20 flex items-center justify-center text-accent`
    *   **Title:** `text-xl font-bold text-white`
    *   **Text:** `text-neutral-400 leading-relaxed`

### C. Details / "How It Works" Section
Alternating layout (Text + Visuals) or Two-Column Split.

*   **Wrapper:** `<section id="how-it-works" class="py-20 lg:py-32 relative">`
*   **Layout:** `flex flex-col lg:flex-row items-center gap-16`
*   **Text Column:**
    *   **Step Icon:** `w-12 h-12 rounded-2xl bg-accent flex items-center justify-center text-black font-bold text-xl shadow-lg`
    *   **Section Title:** `text-3xl md:text-4xl font-bold text-white`
    *   **Highlight Subtitle:** `text-xl text-accent mb-8 font-medium`
    *   **List Items:** Encased in `group p-5 rounded-2xl bg-neutral-800/30 border border-white/5 hover:border-accent/30 transition-colors`
*   **Visual Column:**
    *   **Image Container:** `relative rounded-3xl overflow-hidden border border-white/10 shadow-2xl bg-neutral-900`
    *   **Overlay:** `absolute inset-0 bg-accent/5 group-hover:bg-transparent transition-colors duration-500`

### D. CTA Section
High-impact closing section with gradient background.

*   **Wrapper:** `<section class="py-20">`
*   **Card:** `bg-gradient-to-r from-accent to-secondary rounded-3xl p-12 md:p-20 text-center shadow-2xl relative overflow-hidden`
*   **Texture:** `absolute inset-0 opacity-20 mix-blend-overlay` (noise texture)
*   **Heading:** `text-4xl md:text-6xl font-black text-black`
*   **Button:** Solid black (`bg-black text-white hover:bg-neutral-900`)

---

## 3. Components

### Buttons

1.  **Primary Action (Hero/CTA):**
    ```html
    <a href="#" class="px-8 py-4 bg-accent text-black font-bold rounded-full hover:bg-white hover:text-black transition-all duration-300 transform hover:scale-105 shadow-[0_0_20px_rgba(0,172,193,0.4)]">
      Start Planning
    </a>
    ```

2.  **Secondary Action (Outline):**
    ```html
    <a href="#" class="px-8 py-4 bg-transparent border border-white/30 text-white font-bold rounded-full hover:bg-white/10 transition-all duration-300 backdrop-blur-sm">
      See How It Works
    </a>
    ```

3.  **CTA Section Button (Dark on Bright):**
    ```html
    <a href="#" class="inline-block px-10 py-5 bg-black text-white text-xl font-bold rounded-full hover:bg-neutral-900 transition-all duration-300 transform hover:scale-105 shadow-xl relative z-10">
      Start Free Trial
    </a>
    ```

### Animations

*   **Fade In Up:** Use `animate-fade-in-up` with delays (`delay-100`, `delay-200`, `delay-300`) for cascading entrance of hero elements.
*   **Hover Effects:**
    *   Scale: `transform hover:scale-105`
    *   Glow/Shadow: `shadow-[0_0_20px_rgba(...,0.4)]`
    *   Border Color: `hover:border-accent/30`

### Images & Assets

*   Use `asset_path` for all images.
*   Backgrounds should generally use opacity or overlays (`bg-black/80`) to ensure text readability.
*   Mockups should have rounded corners (`rounded-3xl`) and subtle borders (`border-white/10`).

---

## 4. Helper Classes (Tailwind Config)

Ensure these are available or use arbitrary values as shown above:
*   `bg-accent` -> `#00acc1`
*   `bg-secondary` -> `#f23faf`
*   `bg-neutral-900` -> `#212121`
