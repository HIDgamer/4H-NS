import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Icon, NumberInput, Section, Stack } from '../components';
import { Window } from '../layouts';

const SPAWN_MODES = [
  { value: 'npc', label: 'NPC', icon: 'robot', desc: 'Uncontrolled NPC xeno' },
  { value: 'freed', label: 'Available', icon: 'ghost', desc: 'Ghost players can take over' },
  { value: 'ert', label: 'ERT', icon: 'satellite-dish', desc: 'Launch as Emergency Response Team' },
];

const HIVE_COLORS = {
  'Xenomorph': '#8B3C00',
  'Corrupted': '#5c0066',
  'Runner': '#4a7a1e',
  'Survivor': '#1a3a6e',
  'Mutated': '#8a6600',
  'Dead': '#555',
};

export const AdminSpawnXenos = () => {
  const { act, data } = useBackend();
  const { hives = [], castes = [] } = data;
  const [casteSearch, setCasteSearch] = useState('');
  const [selectedHive, setSelectedHive] = useState(hives[0] || '');
  const [selectedCaste, setSelectedCaste] = useState('');
  const [count, setCount] = useState(1);
  const [range, setRange] = useState(0);
  const [spawnAs, setSpawnAs] = useState('npc');

  const filteredCastes = casteSearch
    ? castes.filter((c) => c.toLowerCase().includes(casteSearch.toLowerCase()))
    : castes;

  const hiveColor = HIVE_COLORS[selectedHive] || '#4a4';

  return (
    <Window title="Create Xenos" theme="hive_status" width={460} height={660}>
      <Window.Content>
        <Stack vertical fill>
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
                      border: selectedHive === h
                        ? `1px solid ${HIVE_COLORS[h] || '#4a4'}`
                        : '1px solid rgba(255,255,255,0.12)',
                      backgroundColor: selectedHive === h
                        ? `${HIVE_COLORS[h] || '#2a6'}22`
                        : 'rgba(255,255,255,0.04)',
                      color: selectedHive === h ? HIVE_COLORS[h] || '#4cff88' : 'rgba(255,255,255,0.6)',
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
                      color: selectedCaste === c ? hiveColor : 'rgba(255,255,255,0.7)',
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

          {/* Count & Range */}
          <Stack.Item>
            <Section title="Spawn Options">
              <Stack>
                <Stack.Item>
                  <Box style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.5)', marginBottom: '3px' }}>Count</Box>
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
                  <Box style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.5)', marginBottom: '3px' }}>Range</Box>
                  <NumberInput
                    value={range}
                    minValue={0}
                    maxValue={10}
                    step={1}
                    width="4rem"
                    onChange={(v) => setRange(v)}
                  />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Spawn mode */}
          <Stack.Item>
            <Section title="Spawn As">
              <Box style={{ display: 'flex', gap: '4px' }}>
                {SPAWN_MODES.map((m) => (
                  <Box
                    key={m.value}
                    as="button"
                    onClick={() => setSpawnAs(m.value)}
                    title={m.desc}
                    style={{
                      flex: 1,
                      padding: '6px 4px',
                      border: spawnAs === m.value ? `1px solid ${hiveColor}` : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor: spawnAs === m.value ? `${hiveColor}22` : 'rgba(255,255,255,0.04)',
                      color: spawnAs === m.value ? hiveColor : 'rgba(255,255,255,0.6)',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '0.78rem',
                      fontWeight: spawnAs === m.value ? 'bold' : 'normal',
                      textAlign: 'center',
                    }}
                  >
                    <Icon name={m.icon} style={{ display: 'block', margin: '0 auto 3px', fontSize: '1rem' }} />
                    {m.label}
                  </Box>
                ))}
              </Box>
            </Section>
          </Stack.Item>

          {/* Spawn button */}
          <Stack.Item>
            <Box style={{ padding: '0 4px' }}>
              {selectedHive && selectedCaste ? (
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
                      hive: selectedHive,
                      caste: selectedCaste,
                      count,
                      range,
                      spawn_as: spawnAs,
                    })
                  }
                >
                  Spawn {count}× {selectedCaste} [{selectedHive}]
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
                  Select hive and caste above
                </Box>
              )}
            </Box>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
