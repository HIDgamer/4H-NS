/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

export type CrtThemeConfig = {
  fg: string;
  bg: string;
  bgDark: string;
  label: string;
};

export const CRT_THEMES: Record<string, CrtThemeConfig> = {
  'crt-green': {
    fg: '#00e94e',
    bg: '#001100',
    bgDark: '#000d00',
    label: 'CRT Green',
  },
  'crt-amber': {
    fg: '#ffbf00',
    bg: '#111100',
    bgDark: '#0a0a00',
    label: 'CRT Amber',
  },
  'crt-blue': {
    fg: '#8ac8ff',
    bg: '#001122',
    bgDark: '#000d1a',
    label: 'CRT Blue',
  },
  'crt-red': {
    fg: '#ff3c3c',
    bg: '#110000',
    bgDark: '#0a0000',
    label: 'CRT Red',
  },
  'crt-purple': {
    fg: '#cc88ff',
    bg: '#110022',
    bgDark: '#0a001a',
    label: 'CRT Purple',
  },
};

export const THEMES = ['dark', 'light'];

const COLOR_DARK_BG = '#202020';
const COLOR_DARK_BG_DARKER = '#171717';
const COLOR_DARK_TEXT = '#a4bad6';

let setClientThemeTimer: NodeJS.Timeout;

/**
 * Theme switching via winset.
 * baseTheme controls TGUI dark/light CSS.
 * colorPreset applies a CRT color overlay on top (null = no overlay).
 *
 * If you change ANYTHING in interface/skin.dmf you need to change it here.
 */
export const setClientTheme = (baseTheme: string, colorPreset: string | null = null) => {
  const effectiveName = colorPreset || baseTheme;
  clearInterval(setClientThemeTimer);
  Byond.command(`.output statbrowser:set_theme ${effectiveName}`);
  setClientThemeTimer = setTimeout(() => {
    Byond.command(`.output statbrowser:set_theme ${effectiveName}`);
  }, 1500);

  const crtConfig = colorPreset ? CRT_THEMES[colorPreset] : null;
  if (crtConfig) {
    return Byond.winset({
      'infowindow.background-color': crtConfig.bg,
      'infowindow.text-color': crtConfig.fg,
      'info.background-color': crtConfig.bg,
      'info.text-color': crtConfig.fg,
      'browseroutput.background-color': crtConfig.bg,
      'browseroutput.text-color': crtConfig.fg,
      'outputwindow.background-color': crtConfig.bg,
      'outputwindow.text-color': crtConfig.fg,
      'mainwindow.background-color': crtConfig.bg,
      'split.background-color': crtConfig.bg,
      'output.background-color': crtConfig.bgDark,
      'output.text-color': crtConfig.fg,
      'statwindow.background-color': crtConfig.bgDark,
      'statwindow.text-color': crtConfig.fg,
      'saybutton.background-color': crtConfig.bg,
      'saybutton.text-color': crtConfig.fg,
      'input.background-color': crtConfig.bg,
      'input.text-color': crtConfig.fg,
      'oocbutton.background-color': crtConfig.bg,
      'oocbutton.text-color': crtConfig.fg,
      'mebutton.background-color': crtConfig.bg,
      'mebutton.text-color': crtConfig.fg,
      'asset_cache_browser.background-color': crtConfig.bg,
      'asset_cache_browser.text-color': crtConfig.fg,
    });
  }

  if (baseTheme === 'light') {
    return Byond.winset({
      // Main windows
      'infowindow.background-color': 'none',
      'infowindow.text-color': '#000000',
      'info.background-color': 'none',
      'info.text-color': '#000000',
      'browseroutput.background-color': 'none',
      'browseroutput.text-color': '#000000',
      'outputwindow.background-color': 'none',
      'outputwindow.text-color': '#000000',
      'mainwindow.background-color': 'none',
      'split.background-color': 'none',
      // Status and verb tabs
      'output.background-color': 'none',
      'output.text-color': '#000000',
      'statwindow.background-color': 'none',
      'statwindow.text-color': '#000000',
      // Say, OOC, me Buttons etc.
      'saybutton.background-color': 'none',
      'saybutton.text-color': '#000000',
      'input.background-color': '#d3b5b5',
      'input.text-color': '#000000',
      'oocbutton.background-color': 'none',
      'oocbutton.text-color': '#000000',
      'mebutton.background-color': 'none',
      'mebutton.text-color': '#000000',
      'asset_cache_browser.background-color': 'none',
      'asset_cache_browser.text-color': '#000000',
    });
  }

  // Default: dark theme
  Byond.winset({
    // Main windows
    'infowindow.background-color': COLOR_DARK_BG,
    'infowindow.text-color': COLOR_DARK_TEXT,
    'info.background-color': COLOR_DARK_BG,
    'info.text-color': COLOR_DARK_TEXT,
    'browseroutput.background-color': COLOR_DARK_BG,
    'browseroutput.text-color': COLOR_DARK_TEXT,
    'outputwindow.background-color': COLOR_DARK_BG,
    'outputwindow.text-color': COLOR_DARK_TEXT,
    'mainwindow.background-color': COLOR_DARK_BG,
    'split.background-color': COLOR_DARK_BG,
    // Status and verb tabs
    'output.background-color': COLOR_DARK_BG_DARKER,
    'output.text-color': COLOR_DARK_TEXT,
    'statwindow.background-color': COLOR_DARK_BG_DARKER,
    'statwindow.text-color': COLOR_DARK_TEXT,
    // Say, OOC, me Buttons etc.
    'saybutton.background-color': COLOR_DARK_BG,
    'saybutton.text-color': COLOR_DARK_TEXT,
    'input.background-color': COLOR_DARK_BG,
    'input.text-color': COLOR_DARK_TEXT,
    'oocbutton.background-color': COLOR_DARK_BG,
    'oocbutton.text-color': COLOR_DARK_TEXT,
    'mebutton.background-color': COLOR_DARK_BG,
    'mebutton.text-color': COLOR_DARK_TEXT,
    'asset_cache_browser.background-color': COLOR_DARK_BG,
    'asset_cache_browser.text-color': COLOR_DARK_TEXT,
  });
};
