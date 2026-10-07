# Phoenix Launcher — Visual Lock v0.1

This document freezes the approved interactive Phoenix Launcher prototype as the visual source of truth for the Android client.

## Rule

The native Kotlin/Compose launcher must reproduce the approved prototype **1:1 in composition and interaction**. Native implementation details may differ, but visible layout must not be redesigned or "improved" independently.

## Locked brand tokens

| Role | Approved value |
| --- | --- |
| Background | `#07080A` |
| Main text | `#EDEFF0` |
| Card / panel | `#101214` |
| Secondary surface | `#171A1D` |
| Accent surface | `#1D2227` |
| Border | `#292B2F` |
| Muted text | `#7E848B` |
| Phoenix orange | `#FE6D1C` |
| Success | `#53CDAB` |
| Danger | `#F14D4C` |
| Art text | `#FAF8F6` |
| Scrim | `#020304` |

## Locked mobile layout

- Main launcher horizontal padding: **20 dp** equivalent.
- Top bar height: **73 dp** equivalent.
- Home welcome block appears immediately below the top bar.
- Main PPA hero height: **487 dp** equivalent on phone.
- Hero corner radius: **10 dp** equivalent.
- Hero title remains the two-line **PHOENIX / PIX ARENA** composition.
- PPA hero has the same upper badges, tags and bottom CTA arrangement.
- Game cards on phone are a horizontal three-card rail, about **154 dp** wide each.
- Bottom navigation has exactly five persistent tabs:
  - Главная
  - Библиотека
  - Новости
  - Профиль
  - Настройки
- Selected bottom tab uses Phoenix orange and a thin top marker, not a Material pill.
- Content leaves room for the fixed bottom navigation.

## Locked screens / flows

1. Splash.
2. Login.
3. Home.
4. Phoenix Pix Arena details.
5. Download / verify / install.
6. Library and filters.
7. News and filters.
8. Profile.
9. Settings.
10. In-game transition placeholder / Phoenix overlay.

Install state must propagate across Home, Library and the PPA detail page in the same session:
`Скачать → Установка → Установлено → Играть`.

## Replaceable content

The layout is locked, but these are deliberately replaceable without redesign:

- Phoenix / game logo art;
- hero art;
- game cards;
- screenshots/gallery;
- game names and descriptions;
- news artwork;
- number of games in the catalog.

Adding a new game must not require changing the launcher screen structure.

## Reference prototype

Project: **Phoenix Launcher Visual Prototype**

The approved Lovable prototype remains the visual QA reference. Native screenshots should be compared against it before a release checkpoint is accepted.


## Responsive behavior

The approved phone portrait layout remains the 1:1 visual reference. Other screen classes adapt without changing the Phoenix visual language.

- **Phone portrait (< 600dp smallest width):** original approved composition; 20dp side padding and 487dp PPA hero.
- **Phone landscape:** compact 60dp top bar / 62dp bottom nav; PPA hero becomes a split layout with art on the left and title/actions on the right.
- **Tablet portrait (>= 600dp smallest width):** larger outer margins, slightly wider game cards, hero remains vertical instead of stretching edge-to-edge.
- **Tablet landscape:** wider margins and split hero layout; content is kept visually bounded instead of scaling every component.
- Rotation is intentionally enabled. The launcher must not force portrait orientation.
- Navigation tab, selected game, download/install state, progress, filters, and settings must survive Activity recreation on rotation.

These adaptive rules may change geometry but must not redesign colors, typography hierarchy, card treatment, navigation structure, or game state behavior.
