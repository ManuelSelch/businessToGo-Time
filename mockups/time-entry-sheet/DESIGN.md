# Time entry sheet exploration

- Revision: 8
- Status: approved for implementation, revision 8; user explicitly approved in chat.
- Goal: compare three native-inspired approaches to creating a time entry: focused form, time-first, and guided two-step.
- Scope: iPhone-sized sheet approximated in a browser; responsive comparison layout. Customer, project, activity, description, start and optional end reflect the existing Kimai sheet. The quick Today flow has a preselected project and fewer fields; it is not represented separately.
- Revision 8: remove the tracking-starts-when-saved caption.
- Revision 7: align Start and End labels, controls, and time text.
- Revision 6: show one direction only, with an End field displaying “Running · tap to set”; leaving it open represents tracking after save, and tapping it allows an end time. Simulated behavior only.
- Revision 5: use the existing brand palette, teal #073E43 and mint #84E2B1, instead of blue accents.
- Revision 4: remove sheet title and back button; use an accessible top-right save icon.
- Revision 3: compare three end-time choices within Familiar & focused only: segmented control, described options, and optional add-end action. Open-ended tracking is the assumed default; mock saving is simulated and does not establish actual timer behavior.
- Revision 2: compact sheet contents, no large in-sheet headings, and top-right Save (or Next in the guided flow) instead of a bottom button. Scrolling remains a fallback for small viewports and larger text.
- Interactions: sample selects and inputs, optional end switch, guided step, and simulated create confirmation. Date is static; displayed duration is illustrative and does not calculate from inputs. No persistence or backend. Selection dependencies and validation are not simulated.
- Open questions: preferred direction; how to handle running/open-ended entries and existing edit and Today journeys in production. No existing behavior removal is approved by this exploration.
- Approval: revision 8, explicitly approved by user in chat.
