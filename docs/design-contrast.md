# Design text contrast

Ratios use the WCAG 2.2 relative-luminance formula. Normal text needs at least 4.5:1; large text needs 3:1. The tables list actual foreground/background pairings used by the current mobile theme and owner review console. Status colors are text and icons on white surfaces, not colored text on same-color chips.

## Flutter mobile tokens

| Text color and background | Ratio |
| --- | ---: |
| Ink `#142D3A` on canvas `#F5F8F8` | 13.41:1 |
| Ink `#142D3A` on surface `#FFFFFF` | 14.32:1 |
| Muted `#526873` on canvas `#F5F8F8` | 5.48:1 |
| Muted `#526873` on surface `#FFFFFF` | 5.86:1 |
| Muted `#526873` on unavailable `#E7ECEE` | 4.92:1 |
| Brand `#087E8B` on canvas `#F5F8F8` | 4.50:1 |
| Brand `#087E8B` on surface `#FFFFFF` | 4.81:1 |
| Brand dark `#075E68` on surface `#FFFFFF` | 7.47:1 |
| Success `#18794E` on surface `#FFFFFF` | 5.41:1 |
| Warning `#9A5B00` on surface `#FFFFFF` | 5.43:1 |
| Danger `#B42318` on surface `#FFFFFF` | 6.57:1 |

Primary button text is white on brand (4.81:1). White on danger is 6.57:1. Disabled/unavailable text uses ink or muted, never white.

## Owner review console

| Text color and background | Ratio |
| --- | ---: |
| Ink `#162523` on canvas `#F5F7F6` | 14.75:1 |
| Ink `#162523` on white `#FFFFFF` | 15.87:1 |
| Muted `#63716D` on canvas `#F5F7F6` | 4.74:1 |
| Muted `#63716D` on white `#FFFFFF` | 5.11:1 |
| Brand `#087F69` on canvas `#F5F7F6` | 4.59:1 |
| Brand `#087F69` on white `#FFFFFF` | 4.94:1 |
| Brand dark `#076858` on selected soft `#E9F5F1` | 6.00:1 |
| Brand dark `#076858` on white `#FFFFFF` | 6.71:1 |
| Danger `#A23535` on reject soft `#FFF5F5` | 6.34:1 |
| Danger `#A23535` on white `#FFFFFF` | 6.78:1 |

The primary button uses white on brand (4.94:1). Text on disabled controls remains the theme's ink or muted color on a white or unavailable surface. Status labels pair text with an icon; no status relies on color alone.
