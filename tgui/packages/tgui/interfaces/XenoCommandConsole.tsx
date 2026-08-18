import { BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import { Box, Button, NumberInput, Section, Stack, Table } from '../components';
import { Window } from '../layouts';

type Xeno = {
  ref: string;
  name: string;
  caste: string;
  health: number;
  max_health: number;
  ai_state: number;
  idle_activity: string;
  area: string;
  selected: number;
  ordered: number;
};

type Data = {
  is_admin_session: number;
  selecting_mode: number;
  armed_order_type: string | null;
  hive_name: string;
  has_rally_point: number;
  roster: Xeno[];
  selected_count: number;
  ai_castes?: string[];
  // Admin-only (is_admin_session) - AI Difficulty, merged in from the
  // former standalone AdminAIDifficulty panel.
  ai_xeno_count?: number;
  ai_flee_multiplier?: number;
  ai_distance_multiplier?: number;
  ai_caste_caps?: Record<string, number>;
  ai_caste_counts?: Record<string, number>;
  difficulty_multiplier?: number;
  spawner_enabled?: BooleanLike;
  spawner_target_population?: number;
  spawner_hive_name?: string;
  spawner_phase?: string;
  ai_debug_pathing?: BooleanLike;
};

const AI_STATE_NAMES: Record<number, string> = {
  1: 'Idle',
  2: 'Approaching',
  3: 'Attacking',
  4: 'Returning',
  5: 'Searching',
};

const healthColor = (health: number, maxHealth: number) => {
  if (!maxHealth) {
    return 'grey';
  }
  const fraction = health / maxHealth;
  if (fraction <= 0.25) {
    return 'bad';
  }
  if (fraction <= 0.6) {
    return 'average';
  }
  return 'good';
};

export const XenoCommandConsole = () => {
  const { act, data } = useBackend<Data>();
  const {
    is_admin_session,
    selecting_mode,
    armed_order_type,
    hive_name = 'Unknown',
    has_rally_point,
    roster = [],
    selected_count = 0,
    ai_castes = [],
    ai_xeno_count = 0,
    ai_flee_multiplier = 1,
    ai_distance_multiplier = 1,
    ai_caste_caps = {},
    ai_caste_counts = {},
    difficulty_multiplier = 1,
    spawner_enabled = false,
    spawner_target_population = 0,
    spawner_hive_name = 'None',
    spawner_phase = 'buildup',
    ai_debug_pathing = false,
  } = data;

  return (
    <Window
      title="Hive Command"
      theme="admin"
      width={720}
      height={is_admin_session ? 1080 : 640}
    >
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Section
              title={`Commanding: ${hive_name}${is_admin_session ? ' (Admin)' : ''}`}
            >
              <Box
                style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.6)' }}
              >
                Select xenos below, by shift-clicking them in-world, or by
                dragging a marquee box - then right-click a destination or an
                enemy on the map to issue a move or attack order. Only
                AI-piloted xenos can be selected or ordered.
              </Box>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title={`Selection (${selected_count})`}>
              <Stack>
                <Stack.Item grow>
                  <Button
                    fluid
                    color={selecting_mode ? 'good' : 'default'}
                    onClick={() => act('toggle_selecting_mode')}
                  >
                    {selecting_mode
                      ? 'Click-to-select: ON'
                      : 'Click-to-select: OFF'}
                  </Button>
                </Stack.Item>
                <Stack.Item grow>
                  <Button fluid onClick={() => act('toggle_marquee_mode')}>
                    Drag-Select Box
                  </Button>
                </Stack.Item>
                <Stack.Item grow>
                  <Button fluid onClick={() => act('select_all')}>
                    Select All
                  </Button>
                </Stack.Item>
                <Stack.Item grow>
                  <Button fluid onClick={() => act('select_none')}>
                    Clear Selection
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Orders">
              <Stack vertical>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Button fluid onClick={() => act('order_hold')}>
                        Hold Position
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        color={
                          armed_order_type === 'focus_fire' ? 'good' : 'default'
                        }
                        onClick={() => act('arm_focus_fire')}
                      >
                        Focus Fire (click target)
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        color={
                          armed_order_type === 'go_to_area' ? 'good' : 'default'
                        }
                        onClick={() => act('arm_go_to_area')}
                      >
                        Go To Area (click map)
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Button fluid onClick={() => act('order_attack_lz')}>
                        Attack the LZ
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button fluid onClick={() => act('order_gather_here')}>
                        Gather Here
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button fluid onClick={() => act('order_form_on_queen')}>
                        Form on the Queen
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button fluid onClick={() => act('order_retreat')}>
                        Retreat to Anchor
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Button
                        fluid
                        color="bad"
                        onClick={() => act('cancel_all_orders')}
                      >
                        Cancel All Orders
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        color={has_rally_point ? 'good' : 'default'}
                        onClick={() => act('order_set_rally')}
                      >
                        Set Rally Point Here
                      </Button>
                    </Stack.Item>
                    <Stack.Item grow>
                      <Button
                        fluid
                        disabled={!has_rally_point}
                        onClick={() => act('order_clear_rally')}
                      >
                        Clear Rally Point
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Stack>
                    <Stack.Item>
                      <Box style={{ fontSize: '0.8rem' }}>
                        Staged order: gather here after
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={10}
                        minValue={1}
                        maxValue={60}
                        step={1}
                        unit="s"
                        width="4rem"
                        onChange={(v) => act('order_delayed', { delay: v })}
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title={`Hive Roster (${roster.length})`}>
              {roster.length === 0 ? (
                <Box color="label" italic>
                  No AI-piloted xenomorphs currently active in this hive.
                </Box>
              ) : (
                <Table>
                  <Table.Row header>
                    <Table.Cell />
                    <Table.Cell>Caste</Table.Cell>
                    <Table.Cell>Health</Table.Cell>
                    <Table.Cell>Status</Table.Cell>
                    <Table.Cell>Location</Table.Cell>
                  </Table.Row>
                  {roster.map((xeno) => (
                    <Table.Row key={xeno.ref}>
                      <Table.Cell>
                        <Button
                          color={xeno.selected ? 'good' : 'default'}
                          onClick={() =>
                            act('toggle_select', { ref: xeno.ref })
                          }
                        >
                          {xeno.selected ? 'Selected' : 'Select'}
                        </Button>
                      </Table.Cell>
                      <Table.Cell bold>{xeno.caste}</Table.Cell>
                      <Table.Cell
                        color={healthColor(xeno.health, xeno.max_health)}
                      >
                        {xeno.health} / {xeno.max_health}
                      </Table.Cell>
                      <Table.Cell>
                        {AI_STATE_NAMES[xeno.ai_state] || 'Unknown'}
                        {xeno.idle_activity ? ` (${xeno.idle_activity})` : ''}
                        {xeno.ordered ? ' ⚙' : ''}
                      </Table.Cell>
                      <Table.Cell>{xeno.area}</Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              )}
            </Section>
          </Stack.Item>

          {!!is_admin_session && (
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
                          Spawning stops entirely if the hive&apos;s Core is
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
                          hive in existence at once, chaos. &quot;None&quot;
                          spawns nothing regardless of the Enabled toggle above.
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Button onClick={() => act('set_spawner_hive')}>
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
          )}

          {!!is_admin_session && (
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
                            act('set_behavior_preset', {
                              preset: 'aggressive',
                            })
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
                          Scales target-scan radius and how far a xeno chases
                          from its anchor.
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
                  <Stack.Item>
                    <Stack>
                      <Stack.Item grow>
                        <Box style={{ fontSize: '0.8rem' }}>
                          Pathing/broadcast debug logging
                        </Box>
                        <Box
                          style={{
                            fontSize: '0.7rem',
                            color: 'rgba(255,255,255,0.5)',
                          }}
                        >
                          Verbose tracing for movement reversals, hive-wide
                          alert-turf changes, and fort-line building - writes to
                          the DEBUG log. Leave off unless actively chasing an
                          issue.
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          color={ai_debug_pathing ? 'good' : 'bad'}
                          onClick={() =>
                            act('set_ai_debug_pathing', {
                              enabled: !ai_debug_pathing,
                            })
                          }
                        >
                          {ai_debug_pathing ? 'Enabled' : 'Disabled'}
                        </Button>
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                </Stack>
              </Section>
            </Stack.Item>
          )}

          {!!is_admin_session && (
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
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};
