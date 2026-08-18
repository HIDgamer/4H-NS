import { playClickBlip } from 'common/audio';
import { BooleanLike } from 'common/react';
import { useState } from 'react';

import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import {
  Box,
  Button,
  Icon,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from '../components';
import { Window } from '../layouts';

type Data = {
  presets: string[];
  hives: string[];
  castes: string[];
  default_tab: 'human' | 'xeno' | 'job';
  preset_target_name: string | null;
  picking: BooleanLike;
  ui_effects_enabled: BooleanLike;
};

type HumanQueueRow = {
  job: string;
  count: number;
};

type XenoQueueRow = {
  hive: string;
  caste: string;
  count: number;
  immature?: boolean;
};

type ModeOption = {
  value: string;
  label: string;
  icon: string;
  desc: string;
};

const ACCENT = '#cc88ff';

const SPAWN_MODES_HUMAN: ModeOption[] = [
  {
    value: 'npc',
    label: 'NPC',
    icon: 'robot',
    desc: 'Spawns as an uncontrolled NPC',
  },
  {
    value: 'freed',
    label: 'Available',
    icon: 'ghost',
    desc: 'Ghost players can take over',
  },
  {
    value: 'ert',
    label: 'ERT',
    icon: 'satellite-dish',
    desc: 'Launch as Emergency Response Team',
  },
];

const EQUIP_MODES: ModeOption[] = [
  {
    value: 'full',
    label: 'Full Gear',
    icon: 'vest',
    desc: 'All standard equipment for the job',
  },
  {
    value: 'no_weapons',
    label: 'No Weapons',
    icon: 'shield-alt',
    desc: 'Gear but no weapons/ammo',
  },
  {
    value: 'no_equipment',
    label: 'Stripped',
    icon: 'user',
    desc: 'No gear except ID card',
  },
];

const SPAWN_MODES_XENO: ModeOption[] = [
  {
    value: 'npc',
    label: 'NPC',
    icon: 'robot',
    desc: 'Uncontrolled, inert xeno',
  },
  {
    value: 'ai',
    label: 'AI',
    icon: 'microchip',
    desc: 'AI-piloted - moves, hunts and attacks on its own. Still ghost-joinable at any time.',
  },
  {
    value: 'freed',
    label: 'Available',
    icon: 'ghost',
    desc: 'Ghost players can take over',
  },
  {
    value: 'ert',
    label: 'ERT',
    icon: 'satellite-dish',
    desc: 'Launch as Emergency Response Team',
  },
];

const HIVE_COLORS: Record<string, string> = {
  Xenomorph: '#8B3C00',
  Corrupted: '#5c0066',
  Runner: '#4a7a1e',
  Survivor: '#1a3a6e',
  Mutated: '#8a6600',
  Dead: '#555',
};

const searchInputStyle = (accent: string): React.CSSProperties => ({
  width: '100%',
  padding: '4px 6px',
  marginBottom: '4px',
  backgroundColor: 'rgba(0,0,0,0.35)',
  border: `1px solid ${accent}66`,
  color: accent,
  borderRadius: '3px',
  fontSize: '0.85rem',
  fontFamily: 'monospace',
});

const modePickerStyle = (
  active: boolean,
  accent: string,
): Partial<CSSStyleDeclaration> => ({
  flex: '1',
  padding: '6px 4px',
  border: active ? `1px solid ${accent}` : '1px solid rgba(255,255,255,0.15)',
  backgroundColor: active ? `${accent}22` : 'rgba(255,255,255,0.04)',
  color: active ? accent : 'rgba(255,255,255,0.6)',
  borderRadius: '3px',
  cursor: 'pointer',
  fontSize: '0.78rem',
  fontWeight: active ? 'bold' : 'normal',
  textAlign: 'center',
});

const PickerRow = (props: {
  readonly label: string;
  readonly selected: boolean;
  readonly accent: string;
  readonly onClick: () => void;
}) => (
  <Box
    as="button"
    onClick={props.onClick}
    style={{
      display: 'block',
      width: '100%',
      padding: '4px 8px',
      textAlign: 'left',
      fontSize: '0.82rem',
      cursor: 'pointer',
      backgroundColor: props.selected ? `${props.accent}33` : 'transparent',
      color: props.selected ? props.accent : 'rgba(255,255,255,0.7)',
      border: 'none',
      borderBottom: '1px solid rgba(255,255,255,0.05)',
      transition: 'background-color 0.1s ease',
    }}
  >
    {props.label}
  </Box>
);

// ─── Job tab ──────────────────────────────────────────────────────────────

const JobPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    presets = [],
    preset_target_name,
    picking = false,
    ui_effects_enabled = true,
  } = data;
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState('');

  const filtered = search
    ? presets.filter((p) => p.toLowerCase().includes(search.toLowerCase()))
    : presets;

  const selectPreset = (p: string) => {
    setSelected(p);
    if (ui_effects_enabled) {
      playClickBlip();
    }
  };

  const apply = () => {
    if (!selected) {
      return;
    }
    if (preset_target_name) {
      act('redress_target', { job: selected });
    } else {
      act('spawn', { panel: 'job', job: selected });
    }
    if (ui_effects_enabled) {
      new Audio(resolveAsset('admin_spawn_confirm.ogg')).play().catch(() => {});
    }
  };

  return (
    <Stack vertical>
      {preset_target_name && (
        <Stack.Item>
          <Box
            style={{
              padding: '6px 8px',
              border: `1px solid ${ACCENT}`,
              borderRadius: '3px',
              backgroundColor: `${ACCENT}18`,
              color: ACCENT,
              fontSize: '0.85rem',
            }}
          >
            <Icon name="user-edit" style={{ marginRight: '6px' }} />
            Redressing: <b>{preset_target_name}</b> - applies immediately, no
            map click needed.
          </Box>
        </Stack.Item>
      )}
      <Stack.Item>
        <Section title="Job / Equipment Preset">
          <input
            placeholder="Search presets…"
            value={search}
            onInput={(e) => setSearch(e.currentTarget.value)}
            style={searchInputStyle(ACCENT)}
          />
          <Box
            style={{
              maxHeight: '420px',
              overflowY: 'auto',
              border: `1px solid ${ACCENT}44`,
              borderRadius: '3px',
            }}
          >
            {filtered.map((p) => (
              <PickerRow
                key={p}
                label={p}
                selected={selected === p}
                accent={ACCENT}
                onClick={() => selectPreset(p)}
              />
            ))}
            {filtered.length === 0 && (
              <Box
                style={{
                  padding: '1rem',
                  textAlign: 'center',
                  color: 'rgba(255,255,255,0.3)',
                  fontStyle: 'italic',
                }}
              >
                No presets match
              </Box>
            )}
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Box style={{ padding: '0 4px' }}>
          {picking ? (
            <Button
              fluid
              icon="crosshairs"
              color="orange"
              className={ui_effects_enabled ? 'admin-glow-pulse' : undefined}
              style={{ padding: '8px', fontSize: '0.95rem' }}
              onClick={() => act('cancel_spawn')}
            >
              Click a human on the map… (Cancel)
            </Button>
          ) : (
            <Button.Confirm
              fluid
              icon="user-edit"
              disabled={!selected}
              style={{
                padding: '8px',
                fontSize: '0.95rem',
                backgroundColor: ACCENT,
                border: `1px solid ${ACCENT}`,
                color: '#110022',
              }}
              onClick={apply}
            >
              {preset_target_name
                ? `Redress ${preset_target_name}`
                : 'Arm Redress (click a human)'}
            </Button.Confirm>
          )}
        </Box>
      </Stack.Item>
    </Stack>
  );
};

// ─── Human tab ────────────────────────────────────────────────────────────

const HumanPanel = () => {
  const { act, data } = useBackend<Data>();
  const { presets = [], picking = false, ui_effects_enabled = true } = data;
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState('');
  const [count, setCount] = useState(1);
  const [range, setRange] = useState(0);
  const [spawnAs, setSpawnAs] = useState('npc');
  const [equipWith, setEquipWith] = useState('full');
  const [queue, setQueue] = useState<HumanQueueRow[]>([]);

  const filtered = search
    ? presets.filter((p) => p.toLowerCase().includes(search.toLowerCase()))
    : presets;

  const selectPreset = (p: string) => {
    setSelected(p);
    if (ui_effects_enabled) {
      playClickBlip();
    }
  };

  const addToQueue = () => {
    if (!selected) {
      return;
    }
    setQueue([...queue, { job: selected, count }]);
    setCount(1);
    if (ui_effects_enabled) {
      playClickBlip();
    }
  };

  const removeFromQueue = (index: number) => {
    setQueue(queue.filter((_, i) => i !== index));
  };

  const spawnQueue = () => {
    act('spawn', {
      panel: 'human',
      queue,
      range,
      spawn_as: spawnAs,
      equip_with: equipWith,
    });
    if (ui_effects_enabled) {
      new Audio(resolveAsset('admin_spawn_confirm.ogg')).play().catch(() => {});
    }
  };

  const totalQueued = queue.reduce((sum, row) => sum + row.count, 0);

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Job / Equipment Preset">
          <input
            placeholder="Search presets…"
            value={search}
            onInput={(e) => setSearch(e.currentTarget.value)}
            style={searchInputStyle(ACCENT)}
          />
          <Box
            style={{
              maxHeight: '220px',
              overflowY: 'auto',
              border: `1px solid ${ACCENT}44`,
              borderRadius: '3px',
            }}
          >
            {filtered.map((p) => (
              <PickerRow
                key={p}
                label={p}
                selected={selected === p}
                accent={ACCENT}
                onClick={() => selectPreset(p)}
              />
            ))}
            {filtered.length === 0 && (
              <Box
                style={{
                  padding: '1rem',
                  textAlign: 'center',
                  color: 'rgba(255,255,255,0.3)',
                  fontStyle: 'italic',
                }}
              >
                No presets match
              </Box>
            )}
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Spawn Options">
          <Stack>
            <Stack.Item>
              <Box
                style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255,255,255,0.5)',
                  marginBottom: '3px',
                }}
              >
                Count
              </Box>
              <NumberInput
                value={count}
                minValue={1}
                maxValue={100}
                step={1}
                width="4rem"
                onChange={(v) => setCount(v)}
              />
            </Stack.Item>
            <Stack.Item>
              <Box
                style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255,255,255,0.5)',
                  marginBottom: '3px',
                }}
              >
                Range
              </Box>
              <NumberInput
                value={range}
                minValue={0}
                maxValue={10}
                step={1}
                width="4rem"
                onChange={(v) => setRange(v)}
              />
            </Stack.Item>
            <Stack.Item grow>
              <Box style={{ marginBottom: '3px' }}>&nbsp;</Box>
              <Button
                fluid
                icon="plus"
                disabled={!selected}
                onClick={addToQueue}
              >
                Add to Queue
              </Button>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      {queue.length > 0 && (
        <Stack.Item>
          <Section title={`Queue (${totalQueued} total)`}>
            <Box style={{ maxHeight: '120px', overflowY: 'auto' }}>
              {queue.map((row, index) => (
                <Box
                  key={index}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '3px 6px',
                    fontSize: '0.82rem',
                    borderBottom: '1px solid rgba(255,255,255,0.06)',
                  }}
                >
                  <Box>
                    {row.count}× {row.job}
                  </Box>
                  <Box
                    as="button"
                    onClick={() => removeFromQueue(index)}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: 'rgba(255,255,255,0.4)',
                      cursor: 'pointer',
                    }}
                  >
                    <Icon name="times" />
                  </Box>
                </Box>
              ))}
            </Box>
          </Section>
        </Stack.Item>
      )}

      <Stack.Item>
        <Section title="Spawn As">
          <Box style={{ display: 'flex', gap: '4px' }}>
            {SPAWN_MODES_HUMAN.map((m) => (
              <Box
                key={m.value}
                as="button"
                onClick={() => setSpawnAs(m.value)}
                style={modePickerStyle(spawnAs === m.value, ACCENT)}
              >
                <Icon
                  name={m.icon}
                  style={{
                    display: 'block',
                    margin: '0 auto 3px',
                    fontSize: '1rem',
                  }}
                />
                {m.label}
              </Box>
            ))}
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Equipment">
          <Box style={{ display: 'flex', gap: '4px' }}>
            {EQUIP_MODES.map((m) => (
              <Box
                key={m.value}
                as="button"
                onClick={() => setEquipWith(m.value)}
                style={modePickerStyle(equipWith === m.value, '#4cff88')}
              >
                <Icon
                  name={m.icon}
                  style={{
                    display: 'block',
                    margin: '0 auto 3px',
                    fontSize: '1rem',
                  }}
                />
                {m.label}
              </Box>
            ))}
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Box style={{ padding: '0 4px' }}>
          {picking ? (
            <Button
              fluid
              icon="crosshairs"
              color="orange"
              className={ui_effects_enabled ? 'admin-glow-pulse' : undefined}
              style={{ padding: '8px', fontSize: '0.95rem' }}
              onClick={() => act('cancel_spawn')}
            >
              Click a tile on the map… (Cancel)
            </Button>
          ) : queue.length > 0 ? (
            <Button.Confirm
              fluid
              icon="user-plus"
              style={{
                padding: '8px',
                fontSize: '0.95rem',
                backgroundColor: ACCENT,
                border: `1px solid ${ACCENT}`,
                color: '#110022',
              }}
              onClick={spawnQueue}
            >
              Spawn Queue ({totalQueued}×)
            </Button.Confirm>
          ) : (
            <Box
              style={{
                textAlign: 'center',
                padding: '8px',
                color: 'rgba(255,255,255,0.3)',
                fontSize: '0.85rem',
                border: '1px dashed rgba(255,255,255,0.1)',
                borderRadius: '3px',
              }}
            >
              <Icon name="hand-pointer" style={{ marginRight: '6px' }} />
              Select a preset, then Add to Queue
            </Box>
          )}
        </Box>
      </Stack.Item>
    </Stack>
  );
};

// ─── Xeno tab ─────────────────────────────────────────────────────────────

const XenoPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    hives = [],
    castes = [],
    picking = false,
    ui_effects_enabled = true,
  } = data;
  const [casteSearch, setCasteSearch] = useState('');
  const [selectedHive, setSelectedHive] = useState(hives[0] || '');
  const [selectedCaste, setSelectedCaste] = useState('');
  const [count, setCount] = useState(1);
  const [range, setRange] = useState(0);
  const [spawnAs, setSpawnAs] = useState('npc');
  const [queue, setQueue] = useState<XenoQueueRow[]>([]);
  const [mode, setMode] = useState<'spawn' | 'burst'>('spawn');
  const [burstType, setBurstType] = useState('larva');
  const [burstTimer, setBurstTimer] = useState(0);
  const [immature, setImmature] = useState(false);

  const filteredCastes = casteSearch
    ? castes.filter((c) => c.toLowerCase().includes(casteSearch.toLowerCase()))
    : castes;

  const hiveColor = HIVE_COLORS[selectedHive] || ACCENT;
  const isQueenSelected = selectedCaste === 'Queen';

  const selectCaste = (c: string) => {
    setSelectedCaste(c);
    if (ui_effects_enabled) {
      playClickBlip();
    }
  };

  const addToQueue = () => {
    if (!selectedHive || !selectedCaste) {
      return;
    }
    setQueue([
      ...queue,
      {
        hive: selectedHive,
        caste: selectedCaste,
        count,
        immature: isQueenSelected ? immature : undefined,
      },
    ]);
    setCount(1);
    if (ui_effects_enabled) {
      playClickBlip();
    }
  };

  const removeFromQueue = (index: number) => {
    setQueue(queue.filter((_, i) => i !== index));
  };

  const playSpawnConfirm = () => {
    if (ui_effects_enabled) {
      new Audio(resolveAsset('admin_spawn_confirm.ogg')).play().catch(() => {});
    }
  };

  const totalQueued = queue.reduce((sum, row) => sum + row.count, 0);
  const availableSpawnModes =
    mode === 'burst'
      ? SPAWN_MODES_XENO.filter((m) => m.value !== 'ert')
      : SPAWN_MODES_XENO;

  return (
    <Stack vertical>
      <Stack.Item>
        <Box style={{ display: 'flex', gap: '4px' }}>
          <Box
            as="button"
            onClick={() => setMode('spawn')}
            style={modePickerStyle(mode === 'spawn', hiveColor)}
          >
            Spawn Caste
          </Box>
          <Box
            as="button"
            onClick={() => setMode('burst')}
            style={modePickerStyle(mode === 'burst', hiveColor)}
          >
            Burst Host
          </Box>
        </Box>
      </Stack.Item>

      <Stack.Item>
        <Section title="Hive">
          <Box style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
            {hives.map((h) => (
              <Box
                key={h}
                as="button"
                onClick={() => setSelectedHive(h)}
                style={{
                  padding: '4px 10px',
                  border:
                    selectedHive === h
                      ? `1px solid ${HIVE_COLORS[h] || ACCENT}`
                      : '1px solid rgba(255,255,255,0.12)',
                  backgroundColor:
                    selectedHive === h
                      ? `${HIVE_COLORS[h] || ACCENT}22`
                      : 'rgba(255,255,255,0.04)',
                  color:
                    selectedHive === h
                      ? HIVE_COLORS[h] || ACCENT
                      : 'rgba(255,255,255,0.6)',
                  borderRadius: '3px',
                  cursor: 'pointer',
                  fontSize: '0.78rem',
                  fontWeight: selectedHive === h ? 'bold' : 'normal',
                  transition: 'all 0.1s ease',
                }}
              >
                {h}
              </Box>
            ))}
          </Box>
        </Section>
      </Stack.Item>

      {mode === 'spawn' && (
        <>
          <Stack.Item grow basis={0}>
            <Section title="Caste" fill>
              <input
                placeholder="Search castes…"
                value={casteSearch}
                onInput={(e) => setCasteSearch(e.currentTarget.value)}
                style={searchInputStyle(hiveColor)}
              />
              <Box
                style={{
                  height: '180px',
                  overflowY: 'auto',
                  border: `1px solid ${hiveColor}44`,
                  borderRadius: '3px',
                }}
              >
                {filteredCastes.map((c) => (
                  <PickerRow
                    key={c}
                    label={c}
                    selected={selectedCaste === c}
                    accent={hiveColor}
                    onClick={() => selectCaste(c)}
                  />
                ))}
                {filteredCastes.length === 0 && (
                  <Box
                    style={{
                      padding: '1rem',
                      textAlign: 'center',
                      color: 'rgba(255,255,255,0.3)',
                      fontStyle: 'italic',
                    }}
                  >
                    No castes match
                  </Box>
                )}
              </Box>
            </Section>
          </Stack.Item>

          {isQueenSelected && (
            <Stack.Item>
              <Section title="Queen Maturity">
                <Box style={{ display: 'flex', gap: '4px' }}>
                  <Box
                    as="button"
                    onClick={() => setImmature(false)}
                    style={modePickerStyle(!immature, hiveColor)}
                  >
                    Mature (has Screech)
                  </Box>
                  <Box
                    as="button"
                    onClick={() => setImmature(true)}
                    style={modePickerStyle(immature, hiveColor)}
                  >
                    Immature (no Screech)
                  </Box>
                </Box>
              </Section>
            </Stack.Item>
          )}

          <Stack.Item>
            <Section title="Spawn Options">
              <Stack>
                <Stack.Item>
                  <Box
                    style={{
                      fontSize: '0.75rem',
                      color: 'rgba(255,255,255,0.5)',
                      marginBottom: '3px',
                    }}
                  >
                    Count
                  </Box>
                  <NumberInput
                    value={count}
                    minValue={1}
                    maxValue={100}
                    step={1}
                    width="4rem"
                    onChange={(v) => setCount(v)}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Box
                    style={{
                      fontSize: '0.75rem',
                      color: 'rgba(255,255,255,0.5)',
                      marginBottom: '3px',
                    }}
                  >
                    Range
                  </Box>
                  <NumberInput
                    value={range}
                    minValue={0}
                    maxValue={10}
                    step={1}
                    width="4rem"
                    onChange={(v) => setRange(v)}
                  />
                </Stack.Item>
                <Stack.Item grow>
                  <Box style={{ marginBottom: '3px' }}>&nbsp;</Box>
                  <Button
                    fluid
                    icon="plus"
                    disabled={!selectedHive || !selectedCaste}
                    onClick={addToQueue}
                  >
                    Add to Queue
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {queue.length > 0 && (
            <Stack.Item>
              <Section title={`Queue (${totalQueued} total)`}>
                <Box style={{ maxHeight: '120px', overflowY: 'auto' }}>
                  {queue.map((row, index) => (
                    <Box
                      key={index}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        padding: '3px 6px',
                        fontSize: '0.82rem',
                        borderBottom: '1px solid rgba(255,255,255,0.06)',
                      }}
                    >
                      <Box>
                        {row.count}× {row.caste}
                        {row.caste === 'Queen' &&
                          (row.immature ? ' (Immature)' : ' (Mature)')}{' '}
                        <Box
                          as="span"
                          style={{ color: HIVE_COLORS[row.hive] || ACCENT }}
                        >
                          [{row.hive}]
                        </Box>
                      </Box>
                      <Box
                        as="button"
                        onClick={() => removeFromQueue(index)}
                        style={{
                          background: 'transparent',
                          border: 'none',
                          color: 'rgba(255,255,255,0.4)',
                          cursor: 'pointer',
                        }}
                      >
                        <Icon name="times" />
                      </Box>
                    </Box>
                  ))}
                </Box>
              </Section>
            </Stack.Item>
          )}
        </>
      )}

      {mode === 'burst' && (
        <Stack.Item>
          <Section title="Burst Type">
            <Box style={{ display: 'flex', gap: '4px' }}>
              <Box
                as="button"
                onClick={() => setBurstType('larva')}
                style={modePickerStyle(burstType === 'larva', hiveColor)}
              >
                <Icon
                  name="bug"
                  style={{ display: 'block', margin: '0 auto 4px' }}
                />
                Larva
              </Box>
              <Box
                as="button"
                onClick={() => setBurstType('hugger')}
                style={modePickerStyle(burstType === 'hugger', hiveColor)}
              >
                <Icon
                  name="spider"
                  style={{ display: 'block', margin: '0 auto 4px' }}
                />
                Hugger
              </Box>
            </Box>
            <Box
              style={{
                marginTop: '10px',
                fontSize: '0.75rem',
                color: 'rgba(255,255,255,0.5)',
                marginBottom: '3px',
              }}
            >
              Timer (seconds, 0 = instant)
            </Box>
            <NumberInput
              value={burstTimer}
              minValue={0}
              maxValue={300}
              step={5}
              width="5rem"
              onChange={(v) => setBurstTimer(v)}
            />
            <Box
              style={{
                marginTop: '6px',
                fontSize: '0.75rem',
                color: 'rgba(255,255,255,0.4)',
              }}
            >
              Click a living human on the map to arm the burst on them.
              {burstTimer > 0 &&
                ` Triggers ${burstTimer}s after clicking, not instantly.`}
            </Box>
          </Section>
        </Stack.Item>
      )}

      <Stack.Item>
        <Section title="Spawn As">
          <Box style={{ display: 'flex', gap: '4px' }}>
            {availableSpawnModes.map((m) => (
              <Box
                key={m.value}
                as="button"
                onClick={() => setSpawnAs(m.value)}
                style={modePickerStyle(spawnAs === m.value, hiveColor)}
              >
                <Icon
                  name={m.icon}
                  style={{
                    display: 'block',
                    margin: '0 auto 3px',
                    fontSize: '1rem',
                  }}
                />
                {m.label}
              </Box>
            ))}
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Box style={{ padding: '0 4px' }}>
          {picking ? (
            <Button
              fluid
              icon="crosshairs"
              color="orange"
              className={ui_effects_enabled ? 'admin-glow-pulse' : undefined}
              style={{ padding: '8px', fontSize: '0.95rem' }}
              onClick={() => act('cancel_spawn')}
            >
              {mode === 'burst'
                ? 'Click a living human… (Cancel)'
                : 'Click a tile on the map… (Cancel)'}
            </Button>
          ) : mode === 'burst' ? (
            <Button.Confirm
              fluid
              icon="bolt"
              disabled={!selectedHive}
              confirmContent="This will kill/convert the targeted human — confirm?"
              style={{
                padding: '8px',
                fontSize: '0.95rem',
                backgroundColor: hiveColor,
                border: `1px solid ${hiveColor}`,
                color: '#fff',
              }}
              onClick={() => {
                act('spawn', {
                  panel: 'xeno',
                  mode: 'burst',
                  hive: selectedHive,
                  burst_type: burstType,
                  spawn_as: spawnAs,
                  timer: burstTimer,
                });
                playSpawnConfirm();
              }}
            >
              Arm {burstType === 'larva' ? 'Larva' : 'Hugger'} Burst
            </Button.Confirm>
          ) : queue.length > 0 ? (
            <Button.Confirm
              fluid
              icon="bug"
              style={{
                padding: '8px',
                fontSize: '0.95rem',
                backgroundColor: hiveColor,
                border: `1px solid ${hiveColor}`,
                color: '#fff',
              }}
              onClick={() => {
                act('spawn', {
                  panel: 'xeno',
                  mode: 'spawn',
                  queue,
                  range,
                  spawn_as: spawnAs,
                });
                playSpawnConfirm();
              }}
            >
              Spawn Queue ({totalQueued}×)
            </Button.Confirm>
          ) : (
            <Box
              style={{
                textAlign: 'center',
                padding: '8px',
                color: 'rgba(255,255,255,0.3)',
                fontSize: '0.85rem',
                border: '1px dashed rgba(255,255,255,0.1)',
                borderRadius: '3px',
              }}
            >
              <Icon name="hand-pointer" style={{ marginRight: '6px' }} />
              Select hive and caste, then Add to Queue
            </Box>
          )}
        </Box>
      </Stack.Item>
    </Stack>
  );
};

// ─── Terminal shell ───────────────────────────────────────────────────────

export const AdminSpawnTerminal = () => {
  const { data } = useBackend<Data>();
  const { default_tab = 'human' } = data;
  const [tab, setTab] = useState<'human' | 'xeno' | 'job'>(default_tab);

  return (
    <Window
      title="Admin Spawn Terminal"
      theme="crtpurple"
      width={500}
      height={820}
    >
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Tabs fluid>
              <Tabs.Tab
                icon="user"
                selected={tab === 'human'}
                onClick={() => setTab('human')}
              >
                Human
              </Tabs.Tab>
              <Tabs.Tab
                icon="bug"
                selected={tab === 'xeno'}
                onClick={() => setTab('xeno')}
              >
                Xeno
              </Tabs.Tab>
              <Tabs.Tab
                icon="id-card"
                selected={tab === 'job'}
                onClick={() => setTab('job')}
              >
                Job
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>
          <Stack.Item grow>
            {tab === 'human' && <HumanPanel />}
            {tab === 'xeno' && <XenoPanel />}
            {tab === 'job' && <JobPanel />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
