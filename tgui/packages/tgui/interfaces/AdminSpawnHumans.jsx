import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Icon, NumberInput, Section, Stack } from '../components';
import { Window } from '../layouts';

const SPAWN_MODES = [
  { value: 'npc', label: 'NPC', icon: 'robot', desc: 'Spawns as an uncontrolled NPC' },
  { value: 'freed', label: 'Available', icon: 'ghost', desc: 'Ghost players can take over' },
  { value: 'ert', label: 'ERT', icon: 'satellite-dish', desc: 'Launch as Emergency Response Team' },
];

const EQUIP_MODES = [
  { value: 'full', label: 'Full Gear', icon: 'vest', desc: 'All standard equipment for the job' },
  { value: 'no_weapons', label: 'No Weapons', icon: 'shield-alt', desc: 'Gear but no weapons/ammo' },
  { value: 'no_equipment', label: 'Stripped', icon: 'user', desc: 'No gear except ID card' },
];

export const AdminSpawnHumans = () => {
  const { act, data } = useBackend();
  const { presets = [] } = data;
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState('');
  const [count, setCount] = useState(1);
  const [range, setRange] = useState(0);
  const [spawnAs, setSpawnAs] = useState('npc');
  const [equipWith, setEquipWith] = useState('full');

  const filtered = search
    ? presets.filter((p) => p.toLowerCase().includes(search.toLowerCase()))
    : presets;

  return (
    <Window title="Create Humans" theme="crtblue" width={480} height={700}>
      <Window.Content>
        <Stack vertical fill>
          {/* Job selection */}
          <Stack.Item>
            <Section title="Job / Equipment Preset">
              <Box
                as="input"
                placeholder="Search presets…"
                value={search}
                onInput={(e) => setSearch(e.target.value)}
                style={{
                  width: '100%',
                  padding: '4px 6px',
                  marginBottom: '4px',
                  backgroundColor: 'rgba(0,0,0,0.3)',
                  border: '1px solid rgba(100,180,255,0.3)',
                  color: '#8cf',
                  borderRadius: '3px',
                  fontSize: '0.85rem',
                }}
              />
              <Box
                style={{
                  maxHeight: '220px',
                  overflowY: 'auto',
                  border: '1px solid rgba(100,180,255,0.15)',
                  borderRadius: '3px',
                }}
              >
                {filtered.map((p) => (
                  <Box
                    key={p}
                    as="button"
                    onClick={() => setSelected(p)}
                    style={{
                      display: 'block',
                      width: '100%',
                      padding: '4px 8px',
                      textAlign: 'left',
                      fontSize: '0.82rem',
                      cursor: 'pointer',
                      backgroundColor:
                        selected === p ? 'rgba(74,140,255,0.25)' : 'transparent',
                      color: selected === p ? '#8cf' : 'rgba(255,255,255,0.7)',
                      border: 'none',
                      borderBottom: '1px solid rgba(255,255,255,0.05)',
                      transition: 'background-color 0.1s ease',
                    }}
                  >
                    {p}
                  </Box>
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

          {/* Spawn options */}
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
                      border: spawnAs === m.value ? '1px solid #4a8cff' : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor: spawnAs === m.value ? 'rgba(74,140,255,0.2)' : 'rgba(255,255,255,0.04)',
                      color: spawnAs === m.value ? '#8cf' : 'rgba(255,255,255,0.6)',
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

          {/* Equipment mode */}
          <Stack.Item>
            <Section title="Equipment">
              <Box style={{ display: 'flex', gap: '4px' }}>
                {EQUIP_MODES.map((m) => (
                  <Box
                    key={m.value}
                    as="button"
                    onClick={() => setEquipWith(m.value)}
                    title={m.desc}
                    style={{
                      flex: 1,
                      padding: '6px 4px',
                      border: equipWith === m.value ? '1px solid #4aff8c' : '1px solid rgba(255,255,255,0.15)',
                      backgroundColor: equipWith === m.value ? 'rgba(74,255,140,0.1)' : 'rgba(255,255,255,0.04)',
                      color: equipWith === m.value ? '#4cff88' : 'rgba(255,255,255,0.6)',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '0.75rem',
                      fontWeight: equipWith === m.value ? 'bold' : 'normal',
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
              {selected ? (
                <Button
                  fluid
                  icon="user-plus"
                  color="green"
                  style={{ padding: '8px', fontSize: '0.95rem' }}
                  onClick={() =>
                    act('spawn', {
                      job: selected,
                      count,
                      range,
                      spawn_as: spawnAs,
                      equip_with: equipWith,
                    })
                  }
                >
                  Spawn {count}× {selected}
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
                  Select a preset above
                </Box>
              )}
            </Box>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
