# Report time entries and timeline

- Revision: 4; status: approved for implementation.
- Goal: explore iPhone report presentations for day, week, month and year. Browser mockup approximates native UI.
- Day: chronological time-scaled timeline with gaps, white entry backgrounds and colored left borders, customer/project context, duration and entry details. A five-minute example uses a larger minimum display height with its actual time shown; collision handling remains unresolved. Week: daily grouped entry list without a section heading, with period chart. Month/year: expandable customer and project summaries with period charts.
- Day timeline and month/year customer summaries have no section heading.
- Shared period switcher, totals, revenue, period navigation and report toolbar preserve the existing visual language. Empty state available through review toggle or `?state=empty`. Direct views: `?view=tag`, `?view=woche`, `?view=monat`, `?view=jahr`.
- Fake data only. Period navigation is illustrative (offset only); totals, charts, detail dates and list data do not update. Filter, timer and calendar controls are visual placeholders. Entry editing/deletion remain intended existing journeys but are not implemented in the mockup. Running entries, overlapping entries, entries outside displayed hours, and dark mode are not yet designed.
- Approval: user explicitly approved implementation after reviewing revision 4 and the stacked collision concept.
