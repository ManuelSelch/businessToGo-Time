# Report period and filters

- Revision: 4; status: approved.
- Goal: native-feeling, consistent week/month/year navigation, a period-specific calendar selector, and combined customer/project/team filters.
- Layout: one segmented period control, previous/next controls surrounding a calendar button, and a toolbar filter button with an active-filter count. Sheets provide a week grid, month grid or year grid, and draft filters with apply/cancel/reset. Calendar selections apply immediately; a close icon dismisses the calendar without changing the selection. Selecting a day selects the Monday–Sunday week.
- Interactive fake data filters by all three dimensions together; conflicting selections show an empty state. Date navigation updates the label and selection, but does not change demo entries or chart data. Chart values are illustrative. No backend, persistence, native behavior or real entry editing. The existing report journeys are not proposed for removal.
- Browser mockup approximates an iPhone; responsive at narrower widths. Tabler icons stand in for native symbols.
- Open questions: single versus multiple selections and any dependency between customer, project and team; actual data availability and permissions.
- Approval: user explicitly approved revision 4 for implementation.
