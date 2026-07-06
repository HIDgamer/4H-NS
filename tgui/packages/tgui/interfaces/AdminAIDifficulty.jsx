import { useBackend } from '../backend';
import { Box, Button, NumberInput, Section, Stack } from '../components';
import { Window } from '../layouts';

export const AdminAIDifficulty = () => {
  const { act, data } = useBackend();
  const {
    ai_xeno_count = 0,
    ai_flee_multiplier = 1,
    ai_distance_multiplier = 1,
    ai_castes = [],
    ai_caste_caps = {},
    ai_caste_counts = {},
    difficulty_multiplier = 1,
    spawner_enabled = false,
    spawner_target_population = 0,
    spawner_hive_name = 'None',
    spawner_phase = 'buildup',
  } = data;

  return (
    <Window title="AI Difficulty" theme="crtblue" width={480} height={760}>
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Section title="Xeno Spawner">
              <Stack vertical>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.85rem' }}>
                        {ai_xeno_count} active / {spawner_target_population}{' '}
                        target
                      </Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        No hard cap - per-caste caps below still apply.
                        Spawning stops entirely if the hive's Core is
                        destroyed.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        color={spawner_enabled ? 'good' : 'bad'}
                        onClick={() =>
                          act('set_spawner_enabled', {
                            enabled: !spawner_enabled,
                          })
                        }
                      >
                        {spawner_enabled ? 'Enabled' : 'Disabled'}
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.8rem' }}>Difficulty</Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        Scales both the target population and how fast the
                        hive spawns toward it. 1x = default.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={difficulty_multiplier}
                        minValue={0.25}
                        maxValue={4}
                        step={0.25}
                        format={(v) => `${v}x`}
                        width="5rem"
                        onChange={(v) =>
                          act('set_spawner_difficulty', { value: v })
                        }
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.8rem' }}>Target hive</Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        Only this one hive is reinforced - used to spawn every
                        hive in existence at once, chaos. "None" spawns
                        nothing regardless of the Enabled toggle above.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        onClick={() => act('set_spawner_hive')}
                      >
                        {spawner_hive_name}
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.8rem' }}>Pressure phase</Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        The hive cycles buildup, assault (hive-wide push at
                        the marines, faster spawning), and lull (spawning
                        paused). Click to force a phase; the normal rhythm
                        resumes from it.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        color={
                          spawner_phase === 'assault'
                            ? 'bad'
                            : spawner_phase === 'lull'
                              ? 'good'
                              : 'average'
                        }
                        onClick={() => act('set_spawner_phase')}
                      >
                        {spawner_phase}
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="AI Behavior">
              <Stack vertical>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Button
                        fluid
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'passive' })
                        }
                      >
                        Passive
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'balanced' })
                        }
                      >
                        Balanced
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'aggressive' })
                        }
                      >
                        Aggressive
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        color="bad"
                        onClick={() =>
                          act('set_behavior_preset', { preset: 'ruthless' })
                        }
                      >
                        Ruthless
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.8rem' }}>Flee threshold</Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        Below 1x fights longer before disengaging.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={ai_flee_multiplier}
                        minValue={0.1}
                        maxValue={3}
                        step={0.1}
                        format={(v) => `${v}x`}
                        width="5rem"
                        onChange={(v) =>
                          act('set_flee_multiplier', { value: v })
                        }
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box style={{ fontSize: '0.8rem' }}>
                        Awareness/leash range
                      </Box>
                      <Box
                        style={{
                          fontSize: '0.7rem',
                          color: 'rgba(255,255,255,0.5)',
                        }}
                      >
                        Scales target-scan radius and how far a xeno chases from
                        its anchor.
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={ai_distance_multiplier}
                        minValue={0.25}
                        maxValue={3}
                        step={0.1}
                        format={(v) => `${v}x`}
                        width="5rem"
                        onChange={(v) =>
                          act('set_distance_multiplier', { value: v })
                        }
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Per-Caste Population Caps">
              <Stack vertical>
                {ai_castes.map((caste) => (
                  <Stack.Item key={caste}>
                    <Stack>
                      <Stack.Item grow>
                        <Box style={{ fontSize: '0.8rem' }}>{caste}</Box>
                        <Box
                          style={{
                            fontSize: '0.7rem',
                            color: 'rgba(255,255,255,0.5)',
                          }}
                        >
                          {ai_caste_counts[caste] || 0} active
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <NumberInput
                          value={ai_caste_caps[caste] || 0}
                          minValue={0}
                          maxValue={100}
                          step={1}
                          format={(v) => (v <= 0 ? 'no cap' : `${v}`)}
                          width="5.5rem"
                          onChange={(v) =>
                            act('set_caste_cap', { caste: caste, value: v })
                          }
                        />
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
