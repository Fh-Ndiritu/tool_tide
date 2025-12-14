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
*   **H2 Headings:** `text-3xl font-bold text-white mt-12 mb-6 border-b border-white/10 pb-4`
*   **H3 Headings:** `text-xl font-semibold text-accent mb-4 mt-8`
*   **Links:** `text-accent hover:text-white underline decoration-accent/30 underline-offset-4 transition-colors`

### Layout Containers

*   **Standard Wrapper:** The content is injected into a container. Ensure extensive use of whitespace.
*   **Feature Box / Callout:**
    ```html
    <div class="bg-neutral-800/50 border border-white/5 rounded-2xl p-8 my-10 backdrop-blur-sm">
      <!-- content -->
    </div>
    ```

## 3. Required Components

### A. The "Local Plant Palette" Grid
When listing plants, DO NOT use a simple bullet list. Use a responsive grid card layout.

```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 my-10">
  <!-- Repeat for each plant -->
  <div class="bg-neutral-800 rounded-xl p-6 border border-white/5 hover:border-accent/50 transition-colors group">
    <h3 class="text-xl font-bold text-white mb-2 group-hover:text-accent transition-colors">[Plant Name]</h3>
    <p class="text-neutral-400 text-sm mb-4">[Short description of why it works here]</p>
    <a href="https://www.google.com/search?q=[Plant Name]+plant" target="_blank" class="text-xs font-bold text-accent uppercase tracking-wider hover:text-white">
      View Images &rarr;
    </a>
  </div>
</div>
```

### B. In-Content CTAs (Contextual)
Place 1-2 contextual CTAs within the body content where relevant (e.g., after discussing specific design styles or plants).

```html
<div class="my-12 p-1 bg-gradient-to-r from-accent/20 to-secondary/20 rounded-2xl">
  <div class="bg-neutral-900 rounded-xl p-8 text-center">
    <h4 class="text-2xl font-bold text-white mb-2">See this in your yard</h4>
    <p class="text-neutral-300 mb-6 max-w-2xl mx-auto">Don't guess. Use Hadaa's <strong>AI Brush</strong> to visualize [Specific Topic from text] instantly.</p>
    <a href="/users/sign_up" class="inline-block px-8 py-3 bg-white text-black font-bold rounded-full hover:bg-accent hover:text-white transition-all transform hover:scale-105">
      Try It Free
    </a>
  </div>
</div>
```

### C. Internal Linking (SEO)
You will be provided with a list of **Related Guides**. You MUST weave these links naturally into the text where relevant, OR create a "Read More" section at the end of a segment.
*   **Format:** `<a href="/landscaping-guides/[slug]" class="...">[Title]</a>`

---

## 4. Image Instructions
*   Use `https://source.unsplash.com/1600x900/?[keyword]` for generic placeholders if needed, but prefer describing the visual so we can replace it with app assets later.
*   For now, leave clear comments: `<!-- INSERT IMAGE: [Description] -->`

## 5. Structural Rules
1.  **No Introduction Fluff:** Start immediately with value.
2.  **Short Paragraphs:** Max 3-4 sentences.
3.  **Mobile Optimization:** Ensure all grids collapse to 1 column on mobile (`grid-cols-1`).
