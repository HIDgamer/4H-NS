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

type Data = {
  current_menu: string;
  logged_in: string;
  access_text: string;
  access_level: number;
  battery_charge: number;
  battery_charge_max: number;
  phone_ringing: boolean;
  is_on_ship: boolean;
  is_on_colony: boolean;
  has_tactical_map: boolean;
  owner_name: string | null;
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

    /* Root wrapper ─ static, so fixed-position overlays work correctly */
    .simi-root {
      background: ${C.bg};
      min-height: 100%;
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

    /* Content sits above overlays; boot animation lives here */
    .simi-content {
      position:relative;
      z-index:1;
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

// ─── External-window banner ───────────────────────────────────────────────────
// Used by any page that launches an interface in a separate popup window.

const ExternalWindowPanel = (props: {
  readonly icon: string;
  readonly label: string;
  readonly statusLine: string;
  readonly statusColor?: string;
  readonly reopenAction: string;
  readonly reopenLabel?: string;
}) => {
  const { act } = useBackend<Data>();
  const {
    icon,
    label,
    statusLine,
    statusColor = 'good',
    reopenAction,
    reopenLabel = 'Reopen Window',
  } = props;

  return (
    <Flex direction="column" align="center" mt={2} mb={2} gap={2}>
      <Box
        fontFamily="monospace"
        fontSize="0.82rem"
        color="label"
        textAlign="center"
        style={{
          border: `1px solid ${C.border}`,
          padding: '4px 10px',
          letterSpacing: '0.12em',
          textTransform: 'uppercase',
        }}
      >
        {label}
      </Box>

      <Box
        fontFamily="monospace"
        fontSize="1.15rem"
        bold
        color={statusColor}
        className="simi-pulse"
      >
        ● {statusLine}
      </Box>

      <Box
        fontFamily="monospace"
        fontSize="0.78rem"
        color="label"
        textAlign="center"
        mt={1}
      >
        Interface launched in external window.
        <br />
        If the window closed, use the button below to reopen it.
      </Box>

      <Button
        icon={icon}
        width="210px"
        textAlign="center"
        p="0.5rem"
        fontSize="0.85rem"
        mt={1}
        onClick={() => act(reopenAction)}
      >
        {reopenLabel}
      </Button>
    </Flex>
  );
};

// ─── Page registry ────────────────────────────────────────────────────────────

const PAGES: Record<string, () => React.ComponentType> = {
  login: () => Login,
  main: () => MainMenu,
  ati_maint: () => AIComms,
  cameras: () => CameraFeed,
  dropship: () => DropshipControl,
  tactical: () => TacticalMap,
  phone: () => Phone,
};

export const SynthBracer = (props) => {
  const { data } = useBackend<Data>();
  const PageComponent = PAGES[data.current_menu]?.() ?? Login;

  return (
    <Window theme="ntos" width={460} height={520}>
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
    phone_ringing,
  } = data;

  const pct = battery_charge / battery_charge_max;
  const batteryColor = pct > 0.6 ? 'good' : pct > 0.2 ? 'average' : 'bad';
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

// ─── AI Comms (Apollo PDA) ────────────────────────────────────────────────────

const AIComms = () => {
  const { data } = useBackend<Data>();
  const { logged_in, access_level } = data;
  const connected = access_level > 0;

  return (
    <>
      <NavHeader />
      <Section title="ARES AI Core — Apollo Interface">
        {connected ? (
          <ExternalWindowPanel
            icon="microchip"
            label={`Secure uplink — ${(logged_in ?? '').toUpperCase()}`}
            statusLine="ARES LINK ESTABLISHED"
            statusColor="good"
            reopenAction="reopen_ati"
            reopenLabel="Reopen Apollo Interface"
          />
        ) : (
          <Flex direction="column" align="center" mt={3} mb={3}>
            <Box fontFamily="monospace" fontSize="1.15rem" bold color="bad">
              ● NOT AUTHENTICATED
            </Box>
            <Box
              fontFamily="monospace"
              fontSize="0.82rem"
              color="label"
              textAlign="center"
              mt={2}
            >
              Insufficient access level for ARES uplink.
            </Box>
          </Flex>
        )}
      </Section>
    </>
  );
};

// ─── Camera Feed ──────────────────────────────────────────────────────────────

const CameraFeed = () => {
  const { data, act } = useBackend<Data>();
  const { is_on_ship, is_on_colony } = data;

  return (
    <>
      <NavHeader />
      <Section title="Camera Surveillance Networks">
        <Flex direction="column" align="center" mt={1} mb={1} gap={1}>
          <Box
            fontFamily="monospace"
            fontSize="0.8rem"
            color="label"
            mb={1}
            style={{ textAlign: 'center', letterSpacing: '0.08em' }}
          >
            AVAILABLE NETWORKS
          </Box>

          {/* Network availability grid */}
          <Flex wrap="wrap" gap={1} justify="center" mb={2}>
            {[
              { label: 'Almayer — Main Deck', available: is_on_ship },
              { label: 'Almayer — Brig', available: is_on_ship },
              { label: 'Almayer — ARES Core', available: is_on_ship },
              { label: 'Alamo — Dropship', available: is_on_ship },
              { label: 'Colony — Ground', available: is_on_colony },
            ].map((net) => (
              <Box
                key={net.label}
                fontFamily="monospace"
                fontSize="0.75rem"
                color={net.available ? 'good' : 'bad'}
                style={{
                  border: `1px solid ${net.available ? C.good + '44' : C.bad + '33'}`,
                  padding: '2px 8px',
                  borderRadius: '2px',
                  opacity: net.available ? '1' : '0.5',
                }}
              >
                {net.available ? '●' : '○'} {net.label}
              </Box>
            ))}
          </Flex>

          <Box
            fontFamily="monospace"
            fontSize="0.78rem"
            color="label"
            textAlign="center"
            mb={2}
          >
            Camera console opens in an external window.
          </Box>

          <Button
            icon="camera"
            width="210px"
            textAlign="center"
            p="0.5rem"
            fontSize="0.9rem"
            onClick={() => act('open_cameras')}
          >
            Open Camera Console
          </Button>
        </Flex>
      </Section>
    </>
  );
};

// ─── Dropship Control ─────────────────────────────────────────────────────────

const DropshipControl = () => {
  const { data } = useBackend<Data>();
  const { is_on_ship } = data;

  return (
    <>
      <NavHeader />
      <Section title="Dropship Flight Computer — Remote">
        {is_on_ship ? (
          <ExternalWindowPanel
            icon="helicopter"
            label="Almayer Flight Control — CIC Mode"
            statusLine="REMOTE LINK ESTABLISHED"
            statusColor="good"
            reopenAction="reopen_dropship"
            reopenLabel="Reopen Flight Computer"
          />
        ) : (
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
        )}
      </Section>
    </>
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
  const { data } = useBackend<Data>();
  const { phone_ringing } = data;

  return (
    <>
      <NavHeader />
      <Section title="Internal Communications">
        <ExternalWindowPanel
          icon="phone"
          label={phone_ringing ? 'INCOMING CALL' : 'Internal Phone'}
          statusLine={phone_ringing ? 'INCOMING CALL' : 'LINE OPEN'}
          statusColor={phone_ringing ? 'bad' : 'good'}
          reopenAction="reopen_phone"
          reopenLabel="Reopen Phone Interface"
        />
      </Section>
    </>
  );
};
