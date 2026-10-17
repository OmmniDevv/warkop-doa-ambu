# DESIGN.md — Warkop Doa Ambu POS

> **Purpose:** A binding UI/UX contract for the Flutter point-of-sale app. Use this document before implementing or changing any screen.
> **Reference direction:** The clarity, confidence, and fast interactions of Gojek/GoPay — inspired by their product principles, not a pixel-for-pixel copy. Warkop Doa Ambu must retain its own identity.

## 1. Product principles

- **Fast at the counter:** A cashier should be able to find products, add items, review the cart, and reach payment with minimal taps.
- **Readable at a glance:** Price, quantity, total, payment state, stock state, and sync state must be easy to distinguish.
- **Trustworthy money handling:** Never make financial actions look ambiguous. Confirm destructive actions and clearly show success/failure.
- **Offline-first:** Offline status is visible but not alarming. Local transactions must remain usable according to existing business rules.
- **Friendly Indonesian identity:** Use concise Bahasa Indonesia for all customer-facing UI.
- **Consistent before clever:** Prefer a coherent, tested component system over decorative one-off screens.

## 2. Visual direction

Create a modern Indonesian fintech / super-app feel: clean white and warm off-white surfaces, confident deep green primary actions, rounded but not excessively pill-shaped components, clear hierarchy, simple line icons, subtle borders, and restrained shadows.

Do **not** copy Gojek/GoPay logos, exact screen layouts, illustrations, or proprietary brand assets. Use them only as broad references for clarity, green-led trust, straightforward navigation, and quick task completion.

### Design keywords
Modern, confident, warm, clean, efficient, approachable, touch-friendly, premium-but-practical.

### Avoid
- Heavy glassmorphism or blur across core transaction screens.
- Gradients on every card, neon glow, excessive shadows, excessive pill shapes.
- Emoji as interface icons.
- Tiny text, low-contrast grey, random corner radii, inconsistent spacing.
- Decorative animation that slows down checkout.
- Rebuilding the whole app architecture to make the UI look different.

## 3. Color tokens

Use semantic tokens centrally through `ThemeData` / `ThemeExtension`. Do not scatter raw hex values throughout screen widgets.

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F6F8F6` | `#101714` | App background |
| `surface` | `#FFFFFF` | `#18211C` | Cards, sheets, inputs |
| `surfaceSubtle` | `#EAF2EC` | `#202D25` | Quiet panels, selected filters |
| `primary` | `#087F5B` | `#38B889` | Main action, selected nav |
| `primaryPressed` | `#066849` | `#2A9A70` | Pressed state |
| `onPrimary` | `#FFFFFF` | `#08251A` | Text/icons on primary |
| `textPrimary` | `#17231D` | `#F2F7F3` | Main text |
| `textSecondary` | `#59675F` | `#B3C0B7` | Supporting text |
| `border` | `#DCE5DE` | `#2D3B32` | Dividers, outlines |
| `success` | `#18794E` | `#62D6A0` | Successful state |
| `warning` | `#8A5A00` | `#F4C15D` | Low stock / attention |
| `warningSurface` | `#FFF2D2` | `#3A2E18` | Warning background |
| `danger` | `#B42318` | `#FF8F85` | Void, destructive action, errors |
| `info` | `#175CD3` | `#84ADFF` | Informational state |

Validate text contrast to WCAG AA: at least 4.5:1 for normal text and 3:1 for large text and meaningful UI boundaries. Do not assume a token pair passes—measure it.

## 4. Typography

- Use the project's already bundled fonts where available; inspect `pubspec.yaml` before adding dependencies.
- Prefer the existing Plus Jakarta Sans font for UI if it is already configured.
- Use clear hierarchy: screen title, section title, body, supporting label, compact metadata.
- Use tabular numerals for prices, quantities, totals, and change where supported.
- Never use Cinzel for general interface text; if already used for the wordmark, keep it limited to branding.
- Do not make critical prices smaller than surrounding descriptions.

Suggested scale:
- Screen title: 24–28sp, semibold/bold
- Section title: 18–20sp, semibold
- Body / controls: 14–16sp
- Supporting metadata: 12–13sp, only when non-critical
- Money total: 24–30sp, bold

## 5. Layout, spacing, and shape

- Base spacing unit: 4dp; use a consistent 4/8/12/16/20/24/32dp scale.
- Main touch targets: at least 48×48dp.
- Standard card radius: 16dp; inputs/buttons: 12–16dp; modal/bottom-sheet top radius: 24dp.
- Use subtle borders before shadows. Shadows should establish elevation, not decoration.
- Keep core cashier actions reachable in the lower portion of the screen where the current layout permits.
- Respect portrait orientation and the existing supported device sizes. Do not assume only one phone resolution.
- Use safe areas and keyboard insets correctly; fields and primary actions must not be hidden by the keyboard.
- Avoid nested scrolling areas unless the interaction clearly requires them.

## 6. Navigation and app structure

Preserve the current route structure, role permissions, and navigation semantics. Do not add or remove destinations without confirming against the PRD and existing implementation.

Where it fits the current app, use a simple bottom navigation with no more than five primary destinations. Use a clear active state (icon + label + indicator), not color alone. Do not introduce a new navigation pattern until the current route inventory is understood.

## 7. Cashier screen requirements

The cashier screen is the highest-priority screen.

### Header
- Show Warkop Doa Ambu identity in a compact header.
- Show shift state and offline/sync state as compact, readable indicators.
- Do not let status indicators crowd out the product search.

### Search and categories
- Search field has a visible label or helpful prompt, clear action, and proper empty/no-results state.
- Category filters must have selected, unselected, and disabled states where relevant.
- Filtering must not reset or silently alter the current cart.

### Product cards
- Use the product photo when `menu.foto` has a valid image.
- If there is no photo, show a deliberate placeholder with category treatment; do not show broken-image icons.
- Show product name and price clearly; add-to-cart must be an obvious, adequately sized control.
- Show low/out-of-stock state using icon + text + color. Disable unavailable products only according to existing stock rules.
- Avoid card heights that jump when names wrap.

### Cart and totals
- Cart item quantity, item price, subtotal, discount (if supported), and total must follow existing business logic.
- Money calculations must follow existing integer/rupiah conventions; UI must not calculate a second, conflicting total.
- Make total and the next action prominent.
- Empty cart, item removal, quantity update, and cart restoration must all have visible feedback.
- Prevent accidental duplicate actions through appropriate in-flight UI state, without hiding legitimate repeated taps.

### Payment
- Use a clear, focused payment surface with amount due, payment method, amount received, and change where applicable.
- Keep the in-app keypad consistent and large enough for touch.
- Validation errors must appear next to the relevant field or action.
- Disable or guard repeat submission while a payment is in progress.
- Success/failure states must accurately reflect the result returned by the existing payment layer; never show success optimistically.
- Do not change receipt format, payment semantics, stock deductions, or transaction persistence as part of a visual redesign.

## 8. Other screens

Apply the same design system to the existing screens confirmed by the code and PRD, including where present:
- Owner login and cashier PIN
- Shift open/close and shift variance
- Open bill and split bill
- Kasbon and kas keluar
- Product catalog, stock, and combo management
- Owner dashboard and reports
- Audit log and transaction history
- Sync status and settings

For tables/lists, prioritize scanning, clear row density, visible status, stable alignment, and useful empty/loading/error states. Charts must have labels and must not rely on color alone.

## 9. States are part of the design

Every asynchronous screen/component must explicitly consider:
- Initial/loading
- Success/normal
- Empty
- Search with no results
- Validation error
- Recoverable operation failure
- Offline / pending sync / sync failed
- Low stock / out of stock
- Disabled / submitting / processing
- Permission denied, where applicable

Use a shared state component where possible. Error text must explain what happened and what the user can do next. Do not expose stack traces or raw database errors to the cashier.

## 10. Motion and feedback

- Keep most transitions around 150–220ms and avoid elaborate choreography.
- Respect reduced-motion settings where feasible.
- Use visual feedback and existing haptic feedback only; do not add sounds.
- Animation must never delay checkout, payment confirmation, or navigation.
- Do not animate layout properties in ways that cause jank on lower-end devices.

## 11. Accessibility and localization

- UI language: Bahasa Indonesia.
- Format currency consistently as Indonesian Rupiah, following the project's existing formatter.
- Ensure icon-only controls have semantic labels.
- Support text scaling without clipping or overflow.
- Maintain visible focus and selected states where keyboard navigation applies.
- Status must be communicated by text/icon as well as color.

## 12. Architecture and implementation boundaries

- Inspect the current architecture and `docs/PRD.md`, `docs/SKEMA_DATABASE.md`, and README before changing files.
- Follow existing naming conventions and project patterns.
- Keep design tokens centralized in `lib/app/tema` if that structure exists; shared components belong in the existing shared-widget folder if that structure exists.
- Do not invent new folders or force this exact folder structure if the repo uses a different convention; map the design system to the actual architecture.
- Do not change database schema, business rules, role permissions, route guards, sync semantics, payment processing, stock deduction, PIN/void rules, or receipt format during a UI-only phase.
- Do not add dependencies unless necessary and explicitly justified.
- Never replace a real provider/repository with fake data in production code. Test fakes belong in tests only.

## 13. Definition of done

A screen is not complete merely because it looks attractive in one screenshot.

Before marking a screen done:
1. Run `flutter analyze`.
2. Run relevant tests and `flutter test`.
3. Add/update widget tests for important screen states and layout constraints.
4. Test light and dark themes if both are supported.
5. Test narrow and typical device widths, plus enlarged text scale.
6. Verify keyboard and bottom-sheet insets.
7. Verify loading, empty, error, offline/sync, and disabled states.
8. Verify the UI calls existing business actions and reflects their actual results.
9. Inspect screenshots and fix visible alignment, clipping, contrast, and spacing issues.
10. Report exact commands run and results. Never claim a test passed if it was not run.

## 14. Change discipline

Use a separate branch. Work in small, reviewable commits. Start with an audit and a pilot screen; do not redesign the entire app in one uncontrolled change. Keep an issue list with severity:
- **P0:** money, payment, duplicate transaction, stock corruption, permission/security
- **P1:** crash, data loss, broken core workflow
- **P2:** layout overflow, blocked controls, incorrect state display
- **P3:** polish and non-critical visual issues

Fix P0/P1 logic bugs separately from visual refactoring. For each logic bug: reproduce it, write a failing test, make the smallest fix, then rerun tests.
