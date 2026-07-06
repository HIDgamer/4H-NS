import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Icon, NumberInput, Section, Stack } from '../components';
import { Window } from '../layouts';

const SPAWN_MODES = [
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

const HIVE_COLORS = {
  Xenomorph: '#8B3C00',
  Corrupted: '#5c0066',
  Runner: '#4a7a1e',
  Survivor: '#1a3a6e',
  Mutated: '#8a6600',
  Dead: '#555',
};

export const AdminSpawnXenos = () => {
  const { act, data } = useBackend();
  const { hives = [], castes = [], picking = false } = data;
  const [casteSearch, setCasteSearch] = useState('');
  const [selectedHive, setSelectedHive] = useState(hives[0] || '');
  const [selectedCaste, setSelectedCaste] = useState('');
  const [count, setCount] = useState(1);
  const [range, setRange] = useState(0);
  const [spawnAs, setSpawnAs] = useState('npc');
  const [queue, setQueue] = useState([]);
  const [mode, setMode] = useState('spawn'); // 'spawn' | 'burst'
  const [burstType, setBurstType] = useState('larva');
  const [immature, setImmature] = useState(false);

  const filteredCastes = casteSearch
    ? castes.filter((c) => c.toLowerCase().includes(casteSearch.toLowerCase()))
    : castes;

  const hiveColor = HIVE_COLORS[selectedHive] || '#4a4';
  const isQueenSelected = selectedCaste === 'Queen';

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
  };

  const removeFromQueue = (index) => {
    setQueue(queue.filter((_, i) => i !== index));
  };

  const totalQueued = queue.reduce((sum, row) => sum + row.count, 0);

  const availableSpawnModes =
    mode === 'burst' ? SPAWN_MODES.filter((m) => m.value !== 'ert') : SPAWN_MODES;

  return (
    <Window title="Create Xenos" theme="hive_status" width={460} height={720}>
      <Window.Content scrollable>
        <Stack vertical>
          {/* Mode toggle */}
          <Stack.Item>
            <Box style={{ display: 'flex', gap: '4px' }}>
              <Box
                as="button"
                onClick={() => setMode('spawn')}
                style={{
                  flex: 1,
                  padding: '5px',
                  border:
                    mode === 'spawn'
                      ? `1px solid ${hiveColor}`
                      : '1px solid rgba(255,255,255,0.15)',
                  backgroundColor:
                    mode === 'spawn' ? `${hiveColor}22` : 'transparent',
                  color: mode === 'spawn' ? hiveColor : 'rgba(255,255,255,0.6)',
                  borderRadius: '3px',
                  cursor: 'pointer',
                  fontSize: '0.82rem',
                  fontWeight: mode === 'spawn' ? 'bold' : 'normal',
                  textAlign: 'center',
                }}
              >
                Spawn Caste
              </Box>
              <Box
                as="button"
                onClick={() => setMode('burst')}
                style={{
                  flex: 1,
                  padding: '5px',
                  border:
                    mode === 'burst'
                      ? `1px solid ${hiveColor}`
                      : '1px solid rgba(255,255,255,0.15)',
                  backgroundColor:
                    mode === 'burst' ? `${hiveColor}22` : 'transparent',
                  color: mode === 'burst' ? hiveColor : 'rgba(255,255,255,0.6)',
                  borderRadius: '3px',
                  cursor: 'pointer',
                  fontSize: '0.82rem',
                  fontWeight: mode === 'burst' ? 'bold' : 'normal',
                  textAlign: 'center',
                }}
              >
                Burst Host
              </Box>
            </Box>
          </Stack.Item>

          {/* Hive selection */}
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
                          ? `1px solid ${HIVE_COLORS[h] || '#4a4'}`
                          : '1px solid rgba(255,255,255,0.12)',
                      backgroundColor:
                        selectedHive === h
                          ? `${HIVE_COLORS[h] || '#2a6'}22`
                          : 'rgba(255,255,255,0.04)',
                      color:
                        selectedHive === h
                          ? HIVE_COLORS[h] || '#4cff88'
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
          {/* Caste selection */}
          <Stack.Item grow basis={0}>
            <Section title="Caste" fill>
              <Box
                as="input"
                placeholder="Search castes…"
                value={casteSearch}
                onInput={(e) => setCasteSearch(e.target.value)}
                style={{
                  width: '100%',
                  padding: '4px 6px',
                  marginBottom: '4px',
                  backgroundColor: 'rgba(0,0,0,0.35)',
                  border: `1px solid ${hiveColor}44`,
                  color: hiveColor,
                  borderRadius: '3px',
                  fontSize: '0.85rem',
                }}
              />
              <Box
                style={{
                  height: '180px',
                  overflowY: 'auto',
                  border: `1px solid ${hiveColor}22`,
                  borderRadius: '3px',
                }}
              >
                {filteredCastes.map((c) => (
                  <Box
                    key={c}
                    as="button"
                    onClick={() => setSelectedCaste(c)}
                    style={{
                      display: 'block',
                      width: '100%',
                      padding: '4px 8px',
                      textAlign: 'left',
                      fontSize: '0.82rem',
                      cursor: 'pointer',
                      backgroundColor:
                        selectedCaste === c ? `${hiveColor}33` : 'transparent',
                      color:
                        selectedCaste === c
                          ? hiveColor
                          : 'rgba(255,255,255,0.7)',
                      border: 'none',
                      borderBottom: '1px solid rgba(255,255,255,0.04)',
                      transition: 'background-color 0.1s ease',
                    }}
                  >
                    {c}
                  </Box>
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
                    style={{
                      flex: 1,
                      padding: '6px 4px',
                      border: !immature
                        ? `1px solid ${hiveColor}`
                        : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor: !immature
                        ? `${hiveColor}22`
                        : 'rgba(255,255,255,0.04)',
                      color: !immature ? hiveColor : 'rgba(255,255,255,0.6)',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '0.8rem',
                      fontWeight: !immature ? 'bold' : 'normal',
                      textAlign: 'center',
                    }}
                  >
                    Mature (has Screech)
                  </Box>
                  <Box
                    as="button"
                    onClick={() => setImmature(true)}
                    style={{
                      flex: 1,
                      padding: '6px 4px',
                      border: immature
                        ? `1px solid ${hiveColor}`
                        : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor: immature
                        ? `${hiveColor}22`
                        : 'rgba(255,255,255,0.04)',
                      color: immature ? hiveColor : 'rgba(255,255,255,0.6)',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '0.8rem',
                      fontWeight: immature ? 'bold' : 'normal',
                      textAlign: 'center',
                    }}
                  >
                    Immature (no Screech)
                  </Box>
                </Box>
              </Section>
            </Stack.Item>
          )}

          {/* Count & Range */}
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

          {/* Queue */}
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
                          style={{ color: HIVE_COLORS[row.hive] || '#4a4' }}
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
                    style={{
                      flex: 1,
                      padding: '8px 4px',
                      border:
                        burstType === 'larva'
                          ? `1px solid ${hiveColor}`
                          : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor:
                        burstType === 'larva'
                          ? `${hiveColor}22`
                          : 'rgba(255,255,255,0.04)',
                      color:
                        burstType === 'larva'
                          ? hiveColor
                          : 'rgba(255,255,255,0.6)',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '0.85rem',
                      fontWeight: burstType === 'larva' ? 'bold' : 'normal',
                      textAlign: 'center',
                    }}
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
                    style={{
                      flex: 1,
                      padding: '8px 4px',
                      border:
                        burstType === 'hugger'
                          ? `1px solid ${hiveColor}`
                          : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor:
                        burstType === 'hugger'
                          ? `${hiveColor}22`
                          : 'rgba(255,255,255,0.04)',
                      color:
                        burstType === 'hugger'
                          ? hiveColor
                          : 'rgba(255,255,255,0.6)',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '0.85rem',
                      fontWeight: burstType === 'hugger' ? 'bold' : 'normal',
                      textAlign: 'center',
                    }}
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
                    marginTop: '6px',
                    fontSize: '0.75rem',
                    color: 'rgba(255,255,255,0.4)',
                  }}
                >
                  Click a living human on the map to burst it out of them.
                </Box>
              </Section>
            </Stack.Item>
          )}

          {/* Spawn mode */}
          <Stack.Item>
            <Section title="Spawn As">
              <Box style={{ display: 'flex', gap: '4px' }}>
                {availableSpawnModes.map((m) => (
                  <Box
                    key={m.value}
                    as="button"
                    onClick={() => setSpawnAs(m.value)}
                    title={m.desc}
                    style={{
                      flex: 1,
                      padding: '6px 4px',
                      border:
                        spawnAs === m.value
                          ? `1px solid ${hiveColor}`
                          : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor:
                        spawnAs === m.value
                          ? `${hiveColor}22`
                          : 'rgba(255,255,255,0.04)',
                      color:
                        spawnAs === m.value
                          ? hiveColor
                          : 'rgba(255,255,255,0.6)',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '0.78rem',
                      fontWeight: spawnAs === m.value ? 'bold' : 'normal',
                      textAlign: 'center',
                    }}
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

          {/* Spawn button */}
          <Stack.Item>
            <Box style={{ padding: '0 4px' }}>
              {picking ? (
                <Button
                  fluid
                  icon="crosshairs"
                  color="orange"
                  style={{ padding: '8px', fontSize: '0.95rem' }}
                  onClick={() => act('cancel_spawn')}
                >
                  {mode === 'burst'
                    ? 'Click a living human… (Cancel)'
                    : 'Click a tile on the map… (Cancel)'}
                </Button>
              ) : mode === 'burst' ? (
                <Button
                  fluid
                  icon="bolt"
                  disabled={!selectedHive}
                  style={{
                    padding: '8px',
                    fontSize: '0.95rem',
                    backgroundColor: hiveColor,
                    border: `1px solid ${hiveColor}`,
                    color: '#fff',
                  }}
                  onClick={() =>
                    act('spawn', {
                      mode: 'burst',
                      hive: selectedHive,
                      burst_type: burstType,
                      spawn_as: spawnAs,
                    })
                  }
                >
                  Arm {burstType === 'larva' ? 'Larva' : 'Hugger'} Burst
                </Button>
              ) : queue.length > 0 ? (
                <Button
                  fluid
                  icon="bug"
                  style={{
                    padding: '8px',
                    fontSize: '0.95rem',
                    backgroundColor: hiveColor,
                    border: `1px solid ${hiveColor}`,
                    color: '#fff',
                  }}
                  onClick={() =>
                    act('spawn', {
                      mode: 'spawn',
                      queue,
                      range,
                      spawn_as: spawnAs,
                    })
                  }
                >
                  Spawn Queue ({totalQueued}×)
                </Button>
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
      </Window.Content>
    </Window>
  );
};
