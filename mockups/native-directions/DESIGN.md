# Native UI directions

- Revision: 3. Status: in review; not approved for implementation.
- Current feedback: remove project/report explanatory notes and workspace info row; replace the offline banner with a toolbar icon; simplify Today to avoid scrolling at the mockup's default phone dimensions.
- Goal: compare three native-feeling iOS treatments using the same synthetic time-tracking content.
- Scope: isolated browser prototypes only. SwiftUI, app dependencies and existing approved weekly-report mockup are unchanged.
- Platform assumption: iPhone first; fixed-width, scrollable phone canvases on desktop and horizontally comparable on narrow screens. Browser components approximate iOS, not UIKit/SwiftUI gestures, materials or Dynamic Type.
- Language: German in all three phone concepts to compare without mixed-language noise; final localization remains a production decision.

## Source-based observations

Read current dashboard, Today routes, app router, report/header, management toolbar, settings and color assets. No native runtime inspection or screenshots performed.

- DashboardView combines a background image, elevated summary card and square customer cards with substantial shadows. Recommend semantic grouped backgrounds, lists, subtle separators and fewer nested surfaces.
- The dashboard greeting is hardcoded. Replace placeholder personalization with date/context or a real localized greeting.
- Existing app theme is blue. Per user feedback, all concepts now use the family branding PDF: teal #073E43 and mint #84E2B1 (page 1). Source: businessToGo ERP/docs/branding/businessToGo-family.pdf, read from the supplied local path. Brand colors are exact; supporting neutral/tinted colors are prototype choices, not prescribed brand tokens.
- Teal is the light-mode action color; mint is the dark-mode action color and timer highlight. Mint buttons use teal text, not white.
- Existing tabs are Today / Projects / Reports. Preserve these three areas; consistent localized labels, icon stroke weights and selected states help recognition.
- Icon-only play/sync/settings controls benefit from consistent 44-point targets, accessible names and clear start/stop labels where the action is consequential.
- Projects remains customer-first. Do not replace customer → project → activity management with recent-project shortcuts.
- Settings must retain accounts/integrations, intro, diagnosis and logout paths. Destructive actions should be separated and confirmed.
- Native production implementation should use NavigationStack, system toolbar/tab bars, SF Symbols, system grouped Lists/Forms, semantic colors, Dynamic Type and VoiceOver, not reproduce these web controls verbatim.

## Compared directions

- Shared: no in-phone businessToGo label, no large screen/date headers. A compact 44px-target toolbar retains labeled “Zeit hinzufügen”, sync and settings. Selected bottom tabs identify the screen; the main landmark retains an accessible label.
- Today keeps daily total, timer and three recent projects. “Heute abgeschlossen” is removed; completed entries remain accessible in Reports. The submitted section locator did not identify a title, so removing the completed section is an explicit interpretation awaiting review. Content is reduced rather than clipped or disabling scrolling; smaller viewports/larger text must remain accessible.
- Project and report explanatory paragraphs and the Kimai workspace info row are removed from phone content. Prototype limitations remain documented here and outside the phones.
- Shared active timer: teal surface with mint duration, status dot and stop control. Retains explicit “Stoppen” text and square icon; idle timer stays neutral.
- A / Native Standard: grouped rows, explicit daily total above the timer. Recommended foundation.
- B / Quiet Focus: more spacious timer and larger duration, daily total below. More emphasis on active work.
- C / Compact Workday: shorter rows, compact timer, subtle selected-tab treatment. Faster scanning at the cost of spaciousness; retain accessible touch targets.
- Management rows no longer show activity counts. Reports uses 80px bars (previously 135px), smaller total text and reduced card padding to expose more entries.

## Review states and interactions

- Route: /native-directions/
- Query parameters: screen=Heute|Projekte|Berichte, state=running|idle|empty|offline, theme=light|dark. Controls update the URL. Reload restores these review choices.
- Global controls reset all phones to the same comparison state. Individual phone tabs navigate independently.
- Interactive: three tabs, start/stop simulation, recent project selection, time-entry form sheet, project search, report period/filter controls and bounded previous/next period samples.
- “Zeit hinzufügen” replaces the ambiguous plus-only header action. It opens the manual time-entry sheet (project, activity, description, start and optional end); available on all three tabs. It does not create a project. Save behavior remains the existing prototype simulation, not a finalized production lifecycle.
- Reports uses deterministic sample bars; selected period is illustrative rather than date-correct reporting. Filters change illustrative totals only. Empty/off-week examples omit entries.
- Offline replaces the sync toolbar icon with a same-sized cloud-off icon, with an accessible name and hover title including pending changes. Tapping reveals simulated status details; there is no persistent offline banner. Offline and sync states are authored examples, not evidence of actual sync correctness.
- Timer digits are static. No live timing, backend, persistence, real accounts, real authentication or production dependency changes.
- Settings sheet is an abbreviated preview; it is not an approved removal of existing settings.
- Agentation is development-only, using local copy/paste annotations; no endpoint or MCP integration.

## Proposed behavior changes — require separate approval

- A visible active timer on Today replaces dashboard-only emphasis.
- Recent-project quick starts supplement (not remove) customer-first navigation.
- Completed entries are accessed/edited through Reports rather than a second Today list.
- Offline replaces the sync icon; status detail is available on demand.
- No approval implied for new pause/resume, automatic retry, background timing, daily targets, billing or automatic synchronization.
- Full CRUD, account switching, customer/project/activity management, team filtering, report calendar/week selection, editing/deletion, settings and logout must remain available if implemented. The abbreviated demo does not authorize their removal.

## Verification and approval

- Dependency installation completed using existing lockfile.
- TypeScript no-emit check passed.
- HTTP HTML/module/style serving checked; startup log inspected. No browser execution or visual verification performed.
- App pipeline intentionally not required for isolated mockups; no production verification claimed.
- npm install reports one high-severity development dependency advisory; no automatic upgrades. Production-only audit reports zero.
- Approval evidence: user likes the timer and prefers green, but has not approved a complete revision or authorized production implementation. Await review of revision 3.
