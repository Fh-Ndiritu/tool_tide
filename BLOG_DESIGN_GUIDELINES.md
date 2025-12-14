# Hadaa Blog UI/UX & Editorial Guidelines

This document defines the design and editorial standards for generating Hadaa blog posts. The goal is to create authoritative, engaging, and visually stunning content that drives SEO and user conversion.

## 1. Editorial Voice & Tone

*   **Authoritative & Expert:** content must feel like it differs from generic "SEO spam". Use specific botanical terms, precise climate data, and hardscape terminology.
*   **Direct & Actionable:** Use the "Inverted Pyramid" style. Answer the user's query immediately in the first paragraph.
*   **Empowering:** Frame problems (e.g., poor soil, drought) as design challenges that Hadaa helps solve.

## 2. Visual Design System (Tailwind CSS)

All content must be returned as raw HTML with inline Tailwind CSS classes. Use the following system to ensure consistency with the master brand.

### Typography (Readability Focused)

*   **Body Text:** `text-lg text-neutral-300 leading-relaxed mb-6 font-light font-sans`
    *   *Note:* We use light text on dark backgrounds (`bg-neutral-900`) for the blog specifically to match the app's premium feel.
*   **H1 Title:** `text-4xl md:text-5xl font-extrabold text-white mb-8 tracking-tight`
*   **H2 Headings:** `text-2xl md:text-3xl font-bold text-white mt-12 mb-6 border-b border-white/10 pb-4`
*   **H3 Headings:** `text-xl font-semibold text-accent mb-4 mt-8`
*   **Links:** `text-accent hover:text-white underline decoration-accent/30 underline-offset-4 transition-colors`

### Layout Containers (Full Width & Responsive)
*   **Main Section Wrappers:** MUST be full screen width to allow background colors to extend fully.
    *   Class: `w-full bg-neutral-900`
*   **Inner Content Constraints:** All text and components must be inside a constrained container to ensure readability.
    *   Class: `container mx-auto px-6 max-w-4xl py-12 md:py-20`
*   **Feature Box / Callout:**
    *   Container: `bg-neutral-800/50 rounded-2xl p-8 my-10 border border-white/5 shadow-2xl backdrop-blur-sm`
    *   Text: `text-neutral-300`

## 3. Required Components

### A. The "Plant Palette" Grid
A responsive grid layout for displaying plant recommendations.
*   **Grid Container:** `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 my-10`
*   **Card Item:** `bg-neutral-800/30 rounded-3xl p-8 border border-white/5 hover:bg-neutral-800/50 transition-all duration-300 hover:-translate-y-2 group`
*   **Icon/Initial:**
    *   Base: `w-12 h-12 rounded-2xl flex items-center justify-center mb-6 group-hover:scale-110 transition-transform font-bold text-xl`
    *   **Color Variety (Rotate these):**
        *   `bg-accent/20 text-accent`
        *   `bg-blue-500/20 text-blue-400`
        *   `bg-green-500/20 text-green-400`
        *   `bg-purple-500/20 text-purple-400`
        *   `bg-rose-500/20 text-rose-400`
*   **Title:** `text-xl font-bold text-white mb-2 group-hover:text-accent transition-colors`
*   **Description:** `text-neutral-400 text-sm mb-4 leading-relaxed`
*   **Link:** `text-xs font-bold text-accent uppercase tracking-wider hover:text-white`

### B. Contextual CTA Section
A prominent call-to-action block to drive user sign-ups.
*   **Outer Gradient Wrapper:** `my-12 p-[1px] bg-gradient-to-r from-accent to-secondary rounded-3xl overflow-hidden shadow-2xl`
*   **Inner Container:** `bg-neutral-900 rounded-[23px] p-8 md:p-12 text-center relative`
*   **Headline:** `text-3xl md:text-4xl font-bold text-white mb-4`
*   **Body:** `text-lg text-neutral-300 mb-8 max-w-2xl mx-auto`
*   **Button:** `inline-block px-10 py-4 bg-white text-black font-bold rounded-full hover:bg-accent hover:text-white transition-all duration-300 transform hover:scale-105 shadow-xl`

### C. Internal Linking (SEO)
Weave links naturally into the text.
*   **Style:** `text-accent hover:text-white transition-colors`

---

## 4. Image Instructions
*   **Placeholder Source:** `https://source.unsplash.com/1600x900/?[keyword]`
*   **Alt Text:** Descriptive and keyword-rich.
*   **Styling:** `rounded-2xl shadow-lg border border-white/10 w-full mb-8`

## 5. Structural Rules
1.  **No Introduction Fluff:** Start immediately with value.
2.  **Short Paragraphs:** Max 3-4 sentences.
3.  **Mobile Optimization:** Ensure all grids collapse to 1 column on mobile (`grid-cols-1`).
