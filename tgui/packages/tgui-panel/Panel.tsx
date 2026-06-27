/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { classes } from 'common/react';
import type { CSSProperties } from 'react';
import { useEffect, useRef } from 'react';
import { Button, Section, Stack } from 'tgui/components';
import { Pane } from 'tgui/layouts';

import { CRT_THEMES } from './themes';

import { NowPlayingWidget, useAudio } from './audio';
import { ChatPanel, ChatTabs } from './chat';
import { useGame } from './game';
import { Notifications } from './Notifications';
import { PingIndicator } from './ping';
import { ReconnectButton } from './reconnect';
import { SettingsPanel, useSettings } from './settings';

// Generates a short CRT-style electronic click via Web Audio API.
const playCrtClick = (fgColor: string) => {
  try {
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.type = 'square';
    osc.frequency.setValueAtTime(880, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(220, ctx.currentTime + 0.04);
    gain.gain.setValueAtTime(0.06, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.06);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.06);
    osc.onended = () => ctx.close();
  } catch {
    // Web Audio unavailable — silent fallback
  }
};

export const Panel = (props) => {
  const audio = useAudio();
  const settings = useSettings();
  const game = useGame();
  const panelRef = useRef<HTMLDivElement>(null);

  const isCrtTheme = !!(settings.colorPreset && CRT_THEMES[settings.colorPreset]);
  const crtConfig = isCrtTheme ? CRT_THEMES[settings.colorPreset] : null;

  // Attach a delegated mousedown listener for CRT click sounds.
  useEffect(() => {
    if (!isCrtTheme || !panelRef.current) return;
    const el = panelRef.current;
    const handleClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (target.closest('.Button')) {
        playCrtClick(crtConfig?.fg ?? '#00e94e');
      }
    };
    el.addEventListener('mousedown', handleClick);
    return () => el.removeEventListener('mousedown', handleClick);
  }, [isCrtTheme, crtConfig]);
  if (process.env.NODE_ENV !== 'production') {
    const { useDebug, KitchenSink } = require('tgui/debug');
    const debug = useDebug();
    if (debug.kitchenSink) {
      return <KitchenSink panel />;
    }
  }

  return (
    <div
      ref={panelRef}
      style={{ height: '100%', width: '100%', display: 'contents' } as CSSProperties}
    >
    <Pane
      theme={settings.theme}
      className={classes([isCrtTheme && 'crt-panel-active'])}
      data-crt-theme={isCrtTheme ? settings.colorPreset : undefined}
      style={
        isCrtTheme && crtConfig
          ? ({
              '--crt-fg': crtConfig.fg,
              '--crt-bg': crtConfig.bg,
            } as CSSProperties)
          : undefined
      }
    >
      <Stack fill vertical>
        <Stack.Item>
          <Section fitted>
            <Stack mr={1} align="center">
              <Stack.Item grow overflowX="auto">
                <ChatTabs />
              </Stack.Item>
              <Stack.Item>
                <PingIndicator />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="grey"
                  selected={audio.visible}
                  icon="music"
                  tooltip="Music player"
                  tooltipPosition="bottom-start"
                  onClick={() => audio.toggle()}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon={settings.visible ? 'times' : 'cog'}
                  selected={settings.visible}
                  tooltip={
                    settings.visible ? 'Close settings' : 'Open settings'
                  }
                  tooltipPosition="bottom-start"
                  onClick={() => settings.toggle()}
                />
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
        {audio.visible && (
          <Stack.Item>
            <Section>
              <NowPlayingWidget />
            </Section>
          </Stack.Item>
        )}
        {settings.visible && (
          <Stack.Item>
            <SettingsPanel />
          </Stack.Item>
        )}
        <Stack.Item grow>
          <Section fill fitted position="relative">
            <Pane.Content scrollable>
              <ChatPanel lineHeight={settings.lineHeight} />
            </Pane.Content>
            <Notifications>
              {game.connectionLostAt && (
                <Notifications.Item rightSlot={<ReconnectButton />}>
                  You are either AFK, experiencing lag or the connection has
                  closed.
                </Notifications.Item>
              )}
              {game.roundRestartedAt && (
                <Notifications.Item>
                  The connection has been closed because the server is
                  restarting. Please wait while you automatically reconnect.
                </Notifications.Item>
              )}
            </Notifications>
          </Section>
        </Stack.Item>
      </Stack>
    </Pane>
    </div>
  );
};
