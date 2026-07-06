import { useBackend } from '../backend';
import { Box, Button, Section, Table } from '../components';
import { Window } from '../layouts';

const AI_STATE_NAMES = {
  1: 'Idle',
  2: 'Approaching',
  3: 'Attacking',
  4: 'Returning',
  5: 'Searching',
};

const healthColor = (health, maxHealth) => {
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

export const AdminHiveStatus = () => {
  const { act, data } = useBackend();
  const { xenos = [] } = data;

  return (
    <Window title="Hive Status" theme="crtblue" width={720} height={520}>
      <Window.Content scrollable>
        <Section title={`AI Xenomorphs (${xenos.length})`}>
          {xenos.length === 0 ? (
            <Box color="label" italic>
              No AI-piloted xenomorphs currently active.
            </Box>
          ) : (
            <Table>
              <Table.Row header>
                <Table.Cell>Callsign</Table.Cell>
                <Table.Cell>Caste</Table.Cell>
                <Table.Cell>Health</Table.Cell>
                <Table.Cell>Status</Table.Cell>
                <Table.Cell>Location</Table.Cell>
                <Table.Cell>Time Lived</Table.Cell>
                <Table.Cell>Damage Dealt</Table.Cell>
                <Table.Cell>Last Ability</Table.Cell>
                <Table.Cell />
              </Table.Row>
              {xenos.map((xeno) => (
                <Table.Row key={xeno.ref}>
                  <Table.Cell bold>{xeno.codename}</Table.Cell>
                  <Table.Cell>{xeno.caste}</Table.Cell>
                  <Table.Cell color={healthColor(xeno.health, xeno.max_health)}>
                    {xeno.health} / {xeno.max_health}
                  </Table.Cell>
                  <Table.Cell>
                    {AI_STATE_NAMES[xeno.ai_state] || 'Unknown'}
                    {xeno.idle_activity ? ` (${xeno.idle_activity})` : ''}
                  </Table.Cell>
                  <Table.Cell>{xeno.area}</Table.Cell>
                  <Table.Cell>{xeno.time_lived}s</Table.Cell>
                  <Table.Cell>{xeno.damage_dealt}</Table.Cell>
                  <Table.Cell>
                    {xeno.last_ability_ago < 0 ? 'never' : `${xeno.last_ability_ago}s ago`}
                  </Table.Cell>
                  <Table.Cell>
                    <Button
                      icon="crosshairs"
                      onClick={() => act('jump_to', { ref: xeno.ref })}
                    >
                      Jump
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
