import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  Flex,
  ProgressBar,
  Section,
  Stack,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

import { CameraContent } from './CameraConsole';
import {
  DropshipDisabledScreen,
  DropshipNavigationProps,
  RenderScreen,
} from './DropshipFlightControl';
import { GeneralPanel } from './PhoneMenu';

type Data = {
  current_menu: string;
  logged_in: string;
  access_text: string;
  access_level: number;
  battery_charge: number;
  battery_charge_max: number;
  // / Fraction of max charge below which the bracer is actually in SIMI_STATUS_LOWPOWER (static data).
  battery_low_ratio: number;
  phone_ringing: boolean;
  is_on_ship: boolean;
  is_on_colony: boolean;
  has_tactical_map: boolean;
  owner_name: string | null;
  active_ability: string;
  active_utility: string;
  motion_detector_active: boolean;
  abilities: Ability[];
};

type Ability = {
  ref: string;
  name: string;
  category: string;
  charge_cost: number;
  cooldown_s: number;
  cooldown_remaining_s: number;
  is_active: boolean;
  can_afford: boolean;
};

// ─── Design tokens ────────────────────────────────────────────────────────────

const C = {
  bg: '#05080f',
  panel: '#090d18',
  panelHover: '#0d1422',
  border: '#152535',
  accent: '#00c8e0',
  accentDim: '#006878',
  text: '#a8d4e8',
  textDim: '#3a5a6e',
  textMuted: '#0e1e28',
  good: '#00d868',
  warn: '#ffaa00',
  bad: '#ff1e40',
} as const;

// ─── CSS injection ────────────────────────────────────────────────────────────
// Strategy: override tgui's own class names (.Section, .Button, etc.) from
// within .simi-root scope. This lets Doc 2's standard components carry the
// SIMI palette without any custom wrapper components.
// The boot animation lives on .simi-boot (a child), NOT on .simi-root, so the
// CRT overlays (::before / ::after) stay fixed while only content animates.

const SIMIStyles = () => (
  <style>
    {`
    @keyframes simi-boot {
      0%   { opacity:0; transform:scaleY(0.05); filter:brightness(6); }
      10%  { opacity:1; transform:scaleY(1);    filter:brightness(2.5); }
      100% { opacity:1; transform:scaleY(1);    filter:brightness(1); }
    }
    @keyframes simi-pulse {
      0%,100% { opacity:1; }
      50%     { opacity:0.35; }
    }
    @keyframes simi-blink {
      0%,49%  { opacity:1; }
      50%,100% { opacity:0; }
    }
    @keyframes simi-flicker {
      0%,92%,100% { opacity:1; }
      93% { opacity:0.55; }
      95% { opacity:1; }
      97% { opacity:0.7; }
    }

    /* Root wrapper ─ static, so fixed-position overlays work correctly.
       height:100% + flex column so pages that need to actually fill the window (Stack fill/grow,
       e.g. the Cameras tab's live ByondUi view) have a real box to size against instead of
       collapsing to auto/content height — without this, ByondUi measures a near-zero bounding
       box and the embedded BYOND map control renders tiny regardless of window size. */
    .simi-root {
      background: ${C.bg};
      height: 100%;
      min-height: 100%;
      display: flex;
      flex-direction: column;
      position: relative;
    }

    /* CRT scanlines ─ fixed to viewport so they never scroll */
    .simi-root::before {
      content:'';
      position:fixed; inset:0;
      background:repeating-linear-gradient(
        0deg, transparent 0, transparent 2px,
        rgba(0,0,0,0.11) 2px, rgba(0,0,0,0.11) 4px
      );
      pointer-events:none;
      z-index:9000;
    }

    /* Vignette */
    .simi-root::after {
      content:'';
      position:fixed; inset:0;
      background:radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.58) 100%);
      pointer-events:none;
      z-index:9001;
    }

    /* Content sits above overlays; boot animation lives here. flex:1 + min-height:0 completes the
       fill chain from .simi-root down to whatever the current page renders — min-height:0 is the
       standard fix for a flex child otherwise refusing to shrink below its content's natural size,
       which would break both scrolling and the Cameras tab's fill/grow sizing. */
    .simi-content {
      position:relative;
      z-index:1;
      flex: 1;
      min-height: 0;
      display: flex;
      flex-direction: column;
      animation:simi-boot 0.32s ease-out forwards;
    }

    /* Animation helpers */
    .simi-pulse   { animation:simi-pulse 2.5s ease-in-out infinite; }
    .simi-blink   { animation:simi-blink 1.1s step-end infinite; }
    .simi-flicker { animation:simi-flicker 9s infinite; }

    /* ── Section ──────────────────────────────────────────────────────── */
    .simi-root .Section {
      background: ${C.panel};
      border: 1px solid ${C.border};
      border-radius: 2px;
      box-shadow: inset 0 0 24px rgba(0,200,224,0.025),
                  0 0 1px ${C.accentDim}44;
    }
    .simi-root .Section__title {
      color: ${C.accent} !important;
      font-family: 'Courier New', Courier, monospace !important;
      font-size: 0.78rem !important;
      letter-spacing: 0.2em !important;
      text-transform: uppercase !important;
      text-shadow: 0 0 8px ${C.accent}66 !important;
      border-bottom: 1px solid ${C.border} !important;
      padding: 0.35rem 0.85rem !important;
      background: linear-gradient(90deg, ${C.accent}0d, transparent 65%) !important;
    }
    /* tgui also uses Section__heading in some builds */
    .simi-root .Section__heading {
      color: ${C.accent} !important;
      font-family: 'Courier New', Courier, monospace !important;
      font-size: 0.78rem !important;
      letter-spacing: 0.2em !important;
      text-transform: uppercase !important;
      text-shadow: 0 0 8px ${C.accent}66 !important;
      border-bottom: 1px solid ${C.border} !important;
      padding: 0.35rem 0.85rem !important;
      background: linear-gradient(90deg, ${C.accent}0d, transparent 65%) !important;
    }
    .simi-root .Section__content {
      padding: 0.55rem 0.7rem !important;
    }

    /* ── Buttons ─────────────────────────────────────────────────────── */
    .simi-root .Button {
      font-family: 'Courier New', Courier, monospace !important;
      font-size: 0.82rem !important;
      letter-spacing: 0.03em !important;
      background: linear-gradient(90deg, ${C.accent}11, ${C.accent}07) !important;
      border: 1px solid ${C.border} !important;
      color: ${C.accent} !important;
      border-radius: 2px !important;
      transition: background 0.1s, box-shadow 0.1s, transform 0.07s !important;
    }
    .simi-root .Button:hover:not(.Button--disabled):not([disabled]) {
      background: ${C.panelHover} !important;
      box-shadow: inset 0 0 0 1px ${C.accent}66,
                  0 0 10px ${C.accent}22 !important;
    }
    .simi-root .Button:active:not(.Button--disabled):not([disabled]) {
      transform: scale(0.985) !important;
    }
    .simi-root .Button--disabled,
    .simi-root .Button[disabled] {
      opacity: 0.32 !important;
      cursor: not-allowed !important;
      box-shadow: none !important;
    }
    /* Color: bad */
    .simi-root .Button--color-bad {
      background: linear-gradient(90deg, ${C.bad}11, ${C.bad}07) !important;
      border-color: ${C.bad}44 !important;
      color: ${C.bad} !important;
    }
    .simi-root .Button--color-bad:hover:not(.Button--disabled):not([disabled]) {
      background: ${C.panelHover} !important;
      box-shadow: inset 0 0 0 1px ${C.bad}66, 0 0 10px ${C.bad}22 !important;
    }
    /* Color: good */
    .simi-root .Button--color-good {
      background: linear-gradient(90deg, ${C.good}11, ${C.good}07) !important;
      border-color: ${C.good}44 !important;
      color: ${C.good} !important;
    }
    .simi-root .Button--color-good:hover:not(.Button--disabled):not([disabled]) {
      background: ${C.panelHover} !important;
      box-shadow: inset 0 0 0 1px ${C.good}66, 0 0 10px ${C.good}22 !important;
    }
    /* Color: average (warn) */
    .simi-root .Button--color-average {
      background: linear-gradient(90deg, ${C.warn}11, ${C.warn}07) !important;
      border-color: ${C.warn}44 !important;
      color: ${C.warn} !important;
    }
    .simi-root .Button--color-average:hover:not(.Button--disabled):not([disabled]) {
      background: ${C.panelHover} !important;
      box-shadow: inset 0 0 0 1px ${C.warn}66, 0 0 10px ${C.warn}22 !important;
    }

    /* ── ProgressBar ─────────────────────────────────────────────────── */
    .simi-root .ProgressBar {
      background: ${C.textMuted} !important;
      border: 1px solid ${C.border} !important;
    }

    /* ── Login authenticate button (not a tgui Button) ───────────────── */
    .simi-login-btn {
      cursor: pointer;
      transition: background 0.15s, box-shadow 0.15s, transform 0.08s;
    }
    .simi-login-btn:hover {
      background: ${C.accentDim}33 !important;
      box-shadow: 0 0 32px ${C.accent}44 !important;
    }
    .simi-login-btn:active {
      transform: scale(0.97);
    }
  `}
  </style>
);

// ─── Corner brackets ──────────────────────────────────────────────────────────

const Corners = ({ color = C.accent }: { readonly color?: string }) => (
  <>
    <Box
      style={{
        position: 'absolute',
        top: '0',
        left: '0',
        width: '9px',
        height: '9px',
        borderTop: `1px solid ${color}`,
        borderLeft: `1px solid ${color}`,
      }}
    />
    <Box
      style={{
        position: 'absolute',
        top: '0',
        right: '0',
        width: '9px',
        height: '9px',
        borderTop: `1px solid ${color}`,
        borderRight: `1px solid ${color}`,
      }}
    />
    <Box
      style={{
        position: 'absolute',
        bottom: '0',
        left: '0',
        width: '9px',
        height: '9px',
        borderBottom: `1px solid ${color}`,
        borderLeft: `1px solid ${color}`,
      }}
    />
    <Box
      style={{
        position: 'absolute',
        bottom: '0',
        right: '0',
        width: '9px',
        height: '9px',
        borderBottom: `1px solid ${color}`,
        borderRight: `1px solid ${color}`,
      }}
    />
  </>
);

// ─── Page registry ────────────────────────────────────────────────────────────

const PAGES: Record<string, () => React.ComponentType> = {
  login: () => Login,
  main: () => MainMenu,
  ati_maint: () => AIComms,
  cameras: () => CameraFeed,
  dropship: () => DropshipControl,
  tactical: () => TacticalMap,
  phone: () => Phone,
  abilities: () => Abilities,
};

// The Cameras and Dropship tabs embed genuinely data/visual-heavy content (a live camera feed
// with a selector list side-by-side; a full flight computer screen) that doesn't fit comfortably
// in the compact size the rest of the wrist computer's pages use — size the window per-page
// instead of picking one compromise size for everything.
// Sized generously above each embedded component's own native standalone-window size (Camera
// 850x708, Dropship 700x500, WorkingJoe 1250x725 before trimming) to leave headroom for the
// bracer's own NavHeader + simi-root/simi-content wrapper stacked on top of it — content designed
// to fill an entire dedicated window on its own needs more than that window's exact size once
// something else is sharing space above it.
const WINDOW_SIZES: Record<string, [number, number]> = {
  cameras: [900, 780],
  dropship: [760, 660],
  phone: [500, 540],
  ati_maint: [720, 700],
};

export const SynthBracer = (props) => {
  const { data } = useBackend<Data>();
  const PageComponent = PAGES[data.current_menu]?.() ?? Login;
  const [width, height] = WINDOW_SIZES[data.current_menu] ?? [460, 520];

  return (
    <Window theme="ntos" width={width} height={height}>
      <SIMIStyles />
      <Window.Content scrollable>
        <Box className="simi-root">
          <Box className="simi-content">
            <PageComponent />
          </Box>
        </Box>
      </Window.Content>
    </Window>
  );
};

// ─── Shared nav header ────────────────────────────────────────────────────────

const NavHeader = () => {
  const { data, act } = useBackend<Data>();
  const {
    logged_in,
    access_text,
    current_menu,
    battery_charge,
    battery_charge_max,
    battery_low_ratio,
    phone_ringing,
  } = data;

  const pct = battery_charge / battery_charge_max;
  const batteryColor =
    pct > 0.6 ? 'good' : pct > battery_low_ratio ? 'average' : 'bad';
  const onMain = current_menu === 'main';

  return (
    <Section>
      <Flex align="center" gap={1}>
        <Flex.Item>
          <Button
            icon="arrow-left"
            tooltip="Go back"
            disabled={onMain}
            onClick={() => act('go_back')}
          />
          <Button
            icon="house"
            tooltip="Main Menu"
            ml={1}
            disabled={onMain}
            onClick={() => act('home')}
          />
        </Flex.Item>

        <Flex.Item grow={1} ml={1}>
          <Box bold fontSize="1rem">
            {logged_in}
          </Box>
          <Box fontSize="0.85rem" color="label">
            {access_text}
          </Box>
        </Flex.Item>

        <Flex.Item width="140px">
          <Box
            fontSize="0.75rem"
            color={batteryColor}
            fontFamily="monospace"
            mb="2px"
          >
            PWR {battery_charge}/{battery_charge_max}
          </Box>
          <ProgressBar
            value={pct}
            minValue={0}
            maxValue={1}
            color={batteryColor}
          />
        </Flex.Item>

        <Flex.Item ml={1}>
          {phone_ringing && (
            <Button
              icon="phone"
              color="bad"
              tooltip="Incoming call!"
              className="simi-pulse"
              mr={1}
              onClick={() => act('page_phone')}
            />
          )}
          <Button.Confirm
            icon="right-from-bracket"
            tooltip="Logout"
            confirmContent="Confirm logout?"
            onClick={() => act('logout')}
          />
        </Flex.Item>
      </Flex>
    </Section>
  );
};

// ─── Login ────────────────────────────────────────────────────────────────────

const Login = () => {
  const { act, data } = useBackend<Data>();
  const { owner_name } = data;

  return (
    <Flex
      direction="column"
      justify="center"
      align="center"
      height="100%"
      mt="1rem"
    >
      <Box
        fontFamily="monospace"
        fontSize="1.8rem"
        bold
        color="label"
        textAlign="center"
        mb={0.5}
      >
        PK-130 SIMI
      </Box>
      <Box
        fontFamily="monospace"
        fontSize="0.9rem"
        color="label"
        textAlign="center"
        mb={0.5}
      >
        WY-DOS Executive v4.2.1
      </Box>
      <Box
        fontFamily="monospace"
        fontSize="0.8rem"
        color="label"
        textAlign="center"
        mb={2}
      >
        © 2182 Weyland-Yutani Corp.
      </Box>
      {owner_name ? (
        <Box
          fontFamily="monospace"
          fontSize="0.8rem"
          color="good"
          textAlign="center"
          mb={2}
        >
          REGISTERED UNIT: {owner_name.toUpperCase()}
        </Box>
      ) : (
        <Box
          fontFamily="monospace"
          fontSize="0.8rem"
          color="average"
          textAlign="center"
          mb={2}
        >
          UNREGISTERED — FIRST SCAN WILL BIND THIS DEVICE
        </Box>
      )}
      <Box
        fontFamily="monospace"
        fontSize="0.8rem"
        color="average"
        textAlign="center"
        mb={3}
      >
        SECURE TERMINAL — SYNTHETIC PERSONNEL ONLY
      </Box>
      <Button
        icon="id-card"
        width="160px"
        textAlign="center"
        fontSize="0.9rem"
        p="0.4rem"
        onClick={() => act('login')}
      >
        Authenticate
      </Button>
    </Flex>
  );
};

// ─── Main Menu ────────────────────────────────────────────────────────────────

const MenuButton = (props: {
  readonly icon: string;
  readonly label: string;
  readonly tooltip?: string;
  readonly color?: string;
  readonly action: string;
  readonly disabled?: boolean;
}) => {
  const { act } = useBackend<Data>();
  const { icon, label, tooltip, color, action, disabled } = props;
  return (
    <Button
      fluid
      icon={icon}
      color={color}
      tooltip={tooltip}
      disabled={disabled}
      onClick={() => act(action)}
      p="0.6rem"
      fontSize="0.9rem"
    >
      {label}
    </Button>
  );
};

const MainMenu = () => {
  const { data } = useBackend<Data>();
  const { phone_ringing, is_on_ship } = data;

  return (
    <>
      <NavHeader />

      <Section title="Communications">
        <Stack fill>
          <Stack.Item grow>
            <MenuButton
              icon="phone"
              label={
                phone_ringing
                  ? 'Internal Phone — INCOMING CALL'
                  : 'Internal Phone'
              }
              tooltip="Access the internal comms network."
              color={phone_ringing ? 'bad' : undefined}
              action="page_phone"
            />
          </Stack.Item>
          <Stack.Item grow>
            <MenuButton
              icon="microchip"
              label="ARES AI Interface"
              tooltip="Open a secure uplink to ARES / Apollo."
              action="page_ati_maint"
            />
          </Stack.Item>
        </Stack>
      </Section>

      <Section title="Monitoring & Control">
        <Stack fill>
          <Stack.Item grow>
            <MenuButton
              icon="camera"
              label="Camera Networks"
              tooltip="Access ship and colony camera feeds."
              action="page_cameras"
            />
          </Stack.Item>
          <Stack.Item grow>
            <MenuButton
              icon="map"
              label="Tactical Map"
              tooltip="View the tactical situation map (requires Tactical Map chip)."
              action="page_tactical"
            />
          </Stack.Item>
        </Stack>
      </Section>

      <Section title="Systems & Abilities">
        <MenuButton
          icon="bolt"
          label="Installed Abilities"
          tooltip="View and activate installed ability modules — anchor, protect, repair, and any chip-installed utilities."
          action="page_abilities"
        />
      </Section>

      <Section title="Flight Operations">
        <MenuButton
          icon="helicopter"
          label={
            is_on_ship
              ? 'Dropship Flight Computer'
              : 'Dropship Flight Computer — UNAVAILABLE'
          }
          tooltip={
            is_on_ship
              ? 'Remotely control dropship navigation (CIC-mode).'
              : 'Must be aboard the ship to access flight controls.'
          }
          color={is_on_ship ? 'average' : undefined}
          disabled={!is_on_ship}
          action="page_dropship"
        />
      </Section>
    </>
  );
};

// ─── Abilities ────────────────────────────────────────────────────────────────
// Lists every action granted by this bracer (inherent + chip-installed) and
// lets the wearer trigger them from here. Triggering routes through the same
// can_use_action()/action_activate() entry point a hotbar click uses
// (code/_onclick/hud/screen_objects.dm), so existing validation, chat
// feedback, cooldowns and charge costs all behave identically either way —
// this is a second control surface for the same abilities, not a reimplementation.

const AbilityRow = (props: { readonly ability: Ability }) => {
  const { act } = useBackend<Data>();
  const { ability } = props;
  const {
    ref,
    name,
    charge_cost,
    cooldown_remaining_s,
    is_active,
    can_afford,
  } = ability;

  const onCooldown = cooldown_remaining_s > 0;
  const disabled = onCooldown || (!can_afford && !is_active);

  let statusLabel = 'Ready';
  let statusColor: string = C.textDim;
  if (is_active) {
    statusLabel = 'Active';
    statusColor = C.accent;
  } else if (onCooldown) {
    statusLabel = `Cooldown ${cooldown_remaining_s}s`;
    statusColor = 'average';
  } else if (!can_afford) {
    statusLabel = `Needs ${charge_cost} charge`;
    statusColor = 'bad';
  }

  return (
    <Flex
      align="center"
      p="0.5rem 0.6rem"
      mb={1}
      style={{
        border: `1px solid ${is_active ? C.accent : C.border}`,
        background: is_active ? C.panelHover : C.panel,
      }}
    >
      <Flex.Item grow={1}>
        <Box fontFamily="monospace" fontSize="0.88rem" bold color={C.text}>
          {name}
        </Box>
        <Box fontFamily="monospace" fontSize="0.75rem" color={statusColor}>
          ● {statusLabel}
          {charge_cost > 0 ? ` — ${charge_cost} charge/use` : ''}
        </Box>
      </Flex.Item>
      <Flex.Item>
        <Button
          icon={is_active ? 'stop' : 'bolt'}
          color={is_active ? 'bad' : undefined}
          disabled={!is_active && disabled}
          tooltip={
            is_active
              ? 'Deactivate'
              : onCooldown
                ? `On cooldown (${cooldown_remaining_s}s remaining)`
                : !can_afford
                  ? 'Not enough charge'
                  : 'Activate'
          }
          onClick={() => act('trigger_ability', { action_ref: ref })}
        >
          {is_active ? 'Stop' : 'Use'}
        </Button>
      </Flex.Item>
    </Flex>
  );
};

const Abilities = () => {
  const { data } = useBackend<Data>();
  const { abilities = [] } = data;

  const primary = abilities.filter((a) => a.category === 'primary');
  const secondary = abilities.filter((a) => a.category !== 'primary');

  return (
    <>
      <NavHeader />
      <Section title="Primary Abilities">
        {primary.length === 0 ? (
          <Box fontFamily="monospace" fontSize="0.8rem" color={C.textDim}>
            No primary ability modules installed.
          </Box>
        ) : (
          primary.map((ability) => (
            <AbilityRow key={ability.ref} ability={ability} />
          ))
        )}
      </Section>
      <Section title="Utility & Integrated Abilities">
        {secondary.length === 0 ? (
          <Box fontFamily="monospace" fontSize="0.8rem" color={C.textDim}>
            No utility modules installed.
          </Box>
        ) : (
          secondary.map((ability) => (
            <AbilityRow key={ability.ref} ability={ability} />
          ))
        )}
      </Section>
    </>
  );
};

// ─── AI Comms (Apollo PDA, trimmed) ────────────────────────────────────────────
//
// Embeds a deliberately reduced subset of WorkingJoe.tsx's pages — login, maintenance
// reporting/management, the wearer's own access-ticket requests, and read-only logs. Excludes
// the facility-wide admin/destructive controls (approving other people's access tickets, nerve
// gas release, AI core lockdown) — see ALLOWED_APOLLO_ACTIONS in bracer_ui.dm for the
// server-enforced side of this trim (these pages simply never render buttons for the excluded
// actions; the server also refuses to forward them regardless of what any client sends).

type MaintenanceTicket = {
  id: number;
  time: string;
  priority_status: boolean;
  category: string;
  details: string;
  status: string;
  submitter: string;
  assignee: string | null;
  lock_status: string;
  ref: string;
};

type AccessTicket = {
  id: number;
  time: string;
  priority_status: boolean;
  title: string;
  details: string;
  status: string;
  submitter: string;
  assignee: string | null;
  lock_status: string;
  ref: string;
};

type ApolloData = {
  local_current_menu: string;
  local_last_page: string;
  local_logged_in: string | null;
  local_access_text: string;
  local_access_level: number;
  apollo_log: string[];
  apollo_access_log: string[];
  maintenance_tickets: MaintenanceTicket[];
  access_tickets: AccessTicket[];
};

const ApolloNavHeader = () => {
  const { data, act } = useBackend<ApolloData>();
  const { local_last_page, local_current_menu } = data;
  return (
    <Flex align="center" mb={1}>
      <Box>
        <Button
          icon="arrow-left"
          tooltip="Go back"
          disabled={local_last_page === local_current_menu}
          onClick={() => act('apollo_go_back')}
        />
        <Button
          icon="house"
          ml={1}
          tooltip="Apollo Menu"
          disabled={local_current_menu === 'main'}
          onClick={() => act('apollo_home')}
        />
      </Box>
      <Box ml="auto">
        <Button.Confirm
          icon="circle-user"
          tooltip="Log out of Apollo"
          confirmContent="Log out of Apollo?"
          onClick={() => act('apollo_logout')}
        >
          Logout
        </Button.Confirm>
      </Box>
    </Flex>
  );
};

const ApolloMain = () => {
  const { data, act } = useBackend<ApolloData>();
  const { local_access_level } = data;

  return (
    <Section title="ARES AI Core — Apollo Interface">
      <Stack vertical>
        {local_access_level <= 2 && (
          <Stack.Item>
            <Button
              icon="bullhorn"
              fluid
              textAlign="center"
              onClick={() => act('page_request')}
            >
              Request Access Ticket
            </Button>
          </Stack.Item>
        )}
        {local_access_level === 3 && (
          <Stack.Item>
            <Button.Confirm
              icon="eye"
              fluid
              textAlign="center"
              onClick={() => act('return_access')}
            >
              Surrender Access Ticket
            </Button.Confirm>
          </Stack.Item>
        )}
        <Stack.Item>
          <Button
            icon="comments"
            fluid
            textAlign="center"
            onClick={() => act('page_report')}
          >
            Maintenance Tickets
          </Button>
        </Stack.Item>
        {local_access_level >= 5 && (
          <Stack.Item>
            <Button
              icon="cart-shopping"
              fluid
              textAlign="center"
              onClick={() => act('page_maintenance')}
            >
              Manage Maintenance Tickets
            </Button>
          </Stack.Item>
        )}
        {local_access_level >= 4 && (
          <>
            <Stack.Item>
              <Button
                icon="clipboard"
                fluid
                textAlign="center"
                onClick={() => act('page_apollo')}
              >
                View Apollo Log
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="users"
                fluid
                textAlign="center"
                onClick={() => act('page_logins')}
              >
                View Access Log
              </Button>
            </Stack.Item>
          </>
        )}
      </Stack>
    </Section>
  );
};

const ApolloLogPage = () => {
  const { data } = useBackend<ApolloData>();
  return (
    <Section title="Apollo Log" fill scrollable>
      {data.apollo_log.map((line, i) => (
        <Box key={i} className="candystripe" p="0.5rem">
          {line}
        </Box>
      ))}
    </Section>
  );
};

const LoginRecordsPage = () => {
  const { data } = useBackend<ApolloData>();
  return (
    <Section title="Login Records" fill scrollable>
      {data.apollo_access_log.map((line, i) => (
        <Box key={i} className="candystripe" p="0.5rem">
          {line}
        </Box>
      ))}
    </Section>
  );
};

const MaintReportsPage = () => {
  const { data, act } = useBackend<ApolloData>();
  const { maintenance_tickets, local_logged_in } = data;
  return (
    <Section title="Maintenance Reports" fill scrollable>
      <Button
        icon="exclamation-circle"
        mb={1}
        onClick={() => act('new_report')}
      >
        New Report
      </Button>
      {maintenance_tickets.map((ticket) => (
        <Flex
          key={ticket.ref}
          className="candystripe"
          p="0.5rem"
          align="center"
        >
          <Flex.Item
            bold
            width="3rem"
            color={ticket.priority_status ? 'bad' : undefined}
          >
            #{ticket.id}
          </Flex.Item>
          <Flex.Item grow>{ticket.details}</Flex.Item>
          <Flex.Item width="6rem" color="label">
            {ticket.status}
          </Flex.Item>
          <Flex.Item>
            <Button.Confirm
              icon="file-circle-xmark"
              tooltip="Cancel Ticket"
              disabled={
                ticket.submitter !== local_logged_in ||
                ticket.lock_status === 'CLOSED'
              }
              onClick={() => act('cancel_ticket', { ticket: ticket.ref })}
            />
          </Flex.Item>
        </Flex>
      ))}
    </Section>
  );
};

const MaintManagementPage = () => {
  const { data, act } = useBackend<ApolloData>();
  const { maintenance_tickets, local_logged_in } = data;
  return (
    <Section title="Maintenance Ticket Management" fill scrollable>
      {maintenance_tickets.map((ticket) => (
        <Flex
          key={ticket.ref}
          className="candystripe"
          p="0.5rem"
          align="center"
        >
          <Flex.Item
            bold
            width="3rem"
            color={ticket.priority_status ? 'bad' : undefined}
          >
            #{ticket.id}
          </Flex.Item>
          <Flex.Item grow>{ticket.details}</Flex.Item>
          <Flex.Item width="8rem" color="label">
            {ticket.assignee ?? 'Unassigned'}
          </Flex.Item>
          <Flex.Item width="6rem" color="label">
            {ticket.status}
          </Flex.Item>
          <Flex.Item>
            <Button.Confirm
              icon="user-lock"
              tooltip="Claim Ticket"
              disabled={ticket.lock_status === 'CLOSED'}
              onClick={() => act('claim_ticket', { ticket: ticket.ref })}
            />
            <Button.Confirm
              icon="user-gear"
              tooltip="Mark Ticket"
              disabled={
                ticket.lock_status === 'CLOSED' ||
                (ticket.assignee !== local_logged_in &&
                  ticket.assignee !== null)
              }
              onClick={() => act('mark_ticket', { ticket: ticket.ref })}
            />
          </Flex.Item>
        </Flex>
      ))}
    </Section>
  );
};

const AccessRequestsPage = () => {
  const { data, act } = useBackend<ApolloData>();
  const { access_tickets, local_logged_in, local_access_level } = data;
  return (
    <Section title="Request Access" fill scrollable>
      <Button
        icon="exclamation-circle"
        mb={1}
        disabled={local_access_level > 2}
        onClick={() => act('new_access')}
      >
        Create Ticket
      </Button>
      {access_tickets.map((ticket) => (
        <Flex
          key={ticket.ref}
          className="candystripe"
          p="0.5rem"
          align="center"
        >
          <Flex.Item bold width="3rem">
            #{ticket.id}
          </Flex.Item>
          <Flex.Item grow>{ticket.details}</Flex.Item>
          <Flex.Item width="6rem" color="label">
            {ticket.status}
          </Flex.Item>
          <Flex.Item>
            <Button.Confirm
              icon="file-circle-xmark"
              tooltip="Cancel Ticket"
              disabled={
                ticket.submitter !== local_logged_in ||
                ticket.lock_status === 'CLOSED'
              }
              onClick={() => act('cancel_ticket', { ticket: ticket.ref })}
            />
          </Flex.Item>
        </Flex>
      ))}
    </Section>
  );
};

const APOLLO_PAGES: Record<string, () => JSX.Element> = {
  main: ApolloMain,
  apollo: ApolloLogPage,
  login_records: LoginRecordsPage,
  maint_reports: MaintReportsPage,
  maint_claim: MaintManagementPage,
  access_requests: AccessRequestsPage,
};

const AIComms = () => {
  const { data, act } = useBackend<Data & ApolloData>();
  const { local_current_menu, local_logged_in, local_access_text } = data;

  if (!local_current_menu || local_current_menu === 'login') {
    return (
      <>
        <NavHeader />
        <Section title="ARES AI Core — Apollo Interface">
          <Flex direction="column" align="center" mt={3} mb={3} gap={2}>
            <Box fontFamily="monospace" fontSize="1.05rem" bold>
              APOLLO Maintenance Controller
            </Box>
            <Box fontFamily="monospace" fontSize="0.8rem" color="label">
              Separate ARES credentials required — scan your ID.
            </Box>
            <Button
              icon="id-card"
              width="60%"
              onClick={() => act('apollo_login')}
            >
              Login
            </Button>
          </Flex>
        </Section>
      </>
    );
  }

  const ApolloPage = APOLLO_PAGES[local_current_menu] ?? ApolloMain;

  return (
    <>
      <NavHeader />
      <Section title={`Apollo — ${local_logged_in}, ${local_access_text}`}>
        <ApolloNavHeader />
        <ApolloPage />
      </Section>
    </>
  );
};

// ─── Camera Feed ──────────────────────────────────────────────────────────────

const CameraFeed = () => {
  return (
    <Stack vertical fill>
      <Stack.Item>
        <NavHeader />
      </Stack.Item>
      <Stack.Item grow>
        <CameraContent />
      </Stack.Item>
    </Stack>
  );
};

// ─── Dropship Control ─────────────────────────────────────────────────────────

const DropshipControl = () => {
  const { data } = useBackend<Data & DropshipNavigationProps>();
  const { is_on_ship, is_disabled } = data;

  return (
    <Stack vertical fill>
      <Stack.Item>
        <NavHeader />
      </Stack.Item>
      <Stack.Item grow>
        {is_on_ship ? (
          is_disabled === 0 ? (
            <RenderScreen />
          ) : (
            <DropshipDisabledScreen />
          )
        ) : (
          <Section fill>
            <Flex direction="column" align="center" mt={3} mb={3}>
              <Box fontFamily="monospace" fontSize="1.15rem" bold color="bad">
                ● LINK UNAVAILABLE
              </Box>
              <Box
                fontFamily="monospace"
                fontSize="0.82rem"
                color="label"
                textAlign="center"
                mt={2}
              >
                Dropship remote access requires ship-side proximity.
              </Box>
            </Flex>
          </Section>
        )}
      </Stack.Item>
    </Stack>
  );
};

// ─── Tactical Map ─────────────────────────────────────────────────────────────

const TacticalMap = () => {
  const { data } = useBackend<Data>();
  const { has_tactical_map } = data;

  return (
    <>
      <NavHeader />
      <Section title="Tactical Situation Map">
        <Flex direction="column" align="center" mt={3} mb={3} gap={2}>
          {has_tactical_map ? (
            <>
              <Box fontFamily="monospace" fontSize="1.1rem" bold color="good">
                ● TACTICAL MAP MODULE ACTIVE
              </Box>
              <Box
                fontFamily="monospace"
                fontSize="0.82rem"
                color="label"
                textAlign="center"
              >
                Use the <b>View Tactical Map</b> action button to open the
                display.
              </Box>
            </>
          ) : (
            <>
              <Box
                fontFamily="monospace"
                fontSize="1.1rem"
                bold
                color="average"
              >
                ● CHIP MODULE REQUIRED
              </Box>
              <Box
                fontFamily="monospace"
                fontSize="0.82rem"
                color="label"
                textAlign="center"
              >
                Install a Tactical Map circuit chip, then use the
                <br />
                <b>View Tactical Map</b> action button to open the display.
              </Box>
            </>
          )}
        </Flex>
      </Section>
    </>
  );
};

// ─── Phone ────────────────────────────────────────────────────────────────────

const Phone = () => {
  return (
    <Stack vertical fill>
      <Stack.Item>
        <NavHeader />
      </Stack.Item>
      <Stack.Item grow>
        <GeneralPanel />
      </Stack.Item>
    </Stack>
  );
};
