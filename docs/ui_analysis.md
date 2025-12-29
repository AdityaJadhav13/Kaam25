# KAAM25 UI Analysis (from reference export)

This document is derived from the imported reference UI in `../kaam25_reference/`.

## Screen List

Auth / gating flow:
- Splash / Launch (Flutter-only placeholder; reference uses direct render)
- Onboarding slides (`OnboardingSlides`)
- Login (`LoginScreen`)
- Pending approval (`PendingApprovalScreen`)
- Blocked (`BlockedScreen`)

Main app shell:
- Main shell with top Stories entry + bottom tabs (`MainApp`)
  - Home / Notes & Documents (`HomeSection`)
    - Folder list view
    - Folder detail: notes + uploaded files list
    - Note detail view
    - File upload confirmation (modal)
    - File preview (modal)
  - Announcements (`AnnouncementsSection`)
    - Announcement list
    - Announcement detail
    - Acknowledge CTA (when required)
    - Attach file (admin-only)
    - File upload confirmation (modal)
    - File preview (modal)
  - Chat (`ChatSection`)
    - Message list (bubble layout)
    - Typing indicator (optional)
    - Composer with attachment + send
    - File upload confirmation (modal)
    - File preview (modal)
  - Stories (`StoriesSection`) (shown as an overlay-mode from the shell)
    - Story list grouped by user
    - Story viewer (dialog)
  - Profile (`ProfileSection`)
    - Profile header
    - Account status summary
    - Settings list
    - Admin tools block (admin-only)

## Reusable Component List

Core UI primitives (used repeatedly):
- Primary / secondary / outline / ghost buttons
- Text inputs (optionally with leading icon)
- Labels
- Badges (including destructive-style count badge)
- Avatar (fallback initials)
- Scrollable area pattern (content + fixed header/footer)
- Card container (border + background)

KAAM25-specific reusable components:
- Bottom navigation item (icon + label + optional badge)
- File card (regular + compact variants)
- File upload button (supports icon-only and labeled variants)
- File upload confirmation dialog
- File preview dialog
- Global upload progress panel (multi-upload list)

## Layout / Navigation Patterns

- Gated entry flow:
  1) Onboarding (first-run)
  2) Login
  3) Status gate (approved/pending/blocked)
  4) Main shell

- Main shell structure:
  - Optional top stories entry strip
  - Tabbed sections via bottom navigation
  - Stories shown as a full-screen mode over the shell

- Detail pages use in-page state + back affordance (folder → note list → note detail, announcement list → detail).

## Data Objects Referenced by UI

The reference UI uses these core types:
- `User`, `Folder`, `Note`, `Announcement`, `Message`, `Story`, `UploadedFile`, `UploadProgress`

See: `../kaam25_reference/src/app/types.ts`.
