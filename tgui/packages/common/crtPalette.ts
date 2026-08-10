/**
 * Canonical CRT color values, shared between the `tgui` package's per-machine CRT theme SCSS
 * (styles/themes/crt/crt-*.scss — used by real machinery consoles, e.g. the Overwatch Console's
 * ui_theme picker, and deliberately left untouched by the admin/chat theme redesign) and
 * `tgui-panel`'s independent chat CRT color-preset system (themes.ts's CRT_THEMES, driving
 * winset() colors for the native output panes).
 *
 * These were previously two disconnected hardcoded palettes that happened to share some values
 * (crt-blue's foreground, crt-green's colors) and drifted on others (crt-blue's background,
 * crt-red's foreground) — this is the single source of truth for the ones that do overlap, so
 * future edits don't silently re-diverge. Not a merge of the SCSS/TS systems themselves (which
 * remain intentionally separate — SCSS can't import TS values, and tgui-panel's system also
 * drives BYOND winset() calls that have no SCSS equivalent at all), just the color values.
 *
 * "purple" has no tgui-package machinery equivalent (no crt-purple.scss exists) — it's
 * chat-exclusive, kept here anyway so this file stays the one place CRT hex values live.
 */
export type CrtColorPair = {
  fg: string;
  bg: string;
};

export const CRT_PALETTE: Record<string, CrtColorPair> = {
  green: { fg: '#00e94e', bg: '#001100' },
  blue: { fg: '#8ac8ff', bg: '#000011' },
  red: { fg: '#d62c2c', bg: '#000011' },
  yellow: { fg: '#ffbf00', bg: '#111100' },
  purple: { fg: '#cc88ff', bg: '#110022' },
};
