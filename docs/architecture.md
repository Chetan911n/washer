# Architecture outline

- `apps/mobile`: single Flutter Android-first app; customer and washer routes share design tokens, while the account role is immutable.
- `apps/admin`: owner-only web panel, backed by server-side admin access.
- `supabase/migrations`: Postgres schema, constraints, indexes and RLS.
- `supabase/functions`: server-controlled pricing, slot availability/holds, payment, reconciliation, dispatch, cancellation/reschedule, refund and payout operations.

## Scheduling and money decisions recorded for Phase 0

Job duration is editable configuration: hatchback 25, sedan 30, SUV 40 minutes, plus wash additions (basic 0, interior vacuum 15, polish 30) and a 10-minute buffer. Society wash windows constrain availability. A slot hold reserves capacity, not a particular washer; assignment follows a verified payment webhook. Assigned jobs cannot overlap for a washer, including duration and buffer. No travel time is modelled within one society.

Daily selfies are private and visible only to a customer with a booking assigned to that washer on that IST day, from assignment until completion. Job photos record capture time and GPS when available; the camera waits up to 20 seconds for a fix, then accepts a no-location photo and flags the booking for admin review. Offline upload is supported. Plate scanning gets two attempts, then typed plate plus a plate photo and admin review flag.

Tips may be paid within 24 hours, use configurable minimum/maximum amounts, pass through 100% to the washer and enter the next payout. Refund deductions carry forward across payouts if one payout cannot cover them; admins can see and write off a remaining balance. Account deletion anonymizes the profile while preserving financial records; photo retention defaults to 90 days, ID documents are deleted within 30 days after washer removal/account deletion, and financial retention has an 8-year placeholder pending accountant guidance.

## Design contrast audit

Contrast ratios are computed from the source token hex values with the WCAG relative-luminance formula. Current text/background pairs in the shared mobile theme are:

| Foreground | Background | Ratio | Result |
|---|---|---:|---|
| Ink `#142D3A` | Canvas `#F5F8F8` | 13.41:1 | Passes AA |
| Ink `#142D3A` | Surface `#FFFFFF` | 14.32:1 | Passes AA |
| Muted `#526873` | Canvas `#F5F8F8` | 5.48:1 | Passes AA |
| Muted `#526873` | Surface `#FFFFFF` | 5.86:1 | Passes AA |
| Brand `#087E8B` | Surface `#FFFFFF` | 4.81:1 | Passes AA |
| Brand dark `#075E68` | Surface `#FFFFFF` | 7.47:1 | Passes AA |
| Success `#18794E` | Surface `#FFFFFF` | 5.41:1 | Passes AA |
| Warning `#9A5B00` | Surface `#FFFFFF` | 5.43:1 | Passes AA |
| Danger `#B42318` | Surface `#FFFFFF` | 6.57:1 | Passes AA |

The brand icon on canvas has 4.42:1 contrast. Borders use `#7F9297` for 3.04:1 on canvas and 3.25:1 on white surfaces. Status components require a Material `IconData`; no emoji are used in status chips.
