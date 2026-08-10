import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Divider,
  Input,
  Section,
  Stack,
  Table,
} from '../components';
import { Window } from '../layouts';

type PlayerEntry = {
  name: string;
  real_name: string;
  key: string;
  job: string;
  ref: string;
  ip: string;
  stat: number;
};

type AdminPlayerListData = {
  players: PlayerEntry[];
  check_antag_enabled: boolean;
};

export const AdminPlayerList = () => {
  const { act, data } = useBackend<AdminPlayerListData>();
  const { players, check_antag_enabled } = data;

  const [filter, setFilter] = useState('');
  const [expandedRef, setExpandedRef] = useState<string | null>(null);

  const lowerFilter = filter.toLowerCase();
  const filtered = filter
    ? players.filter(
        (p) =>
          p.name.toLowerCase().includes(lowerFilter) ||
          p.real_name.toLowerCase().includes(lowerFilter) ||
          p.key.toLowerCase().includes(lowerFilter) ||
          p.job.toLowerCase().includes(lowerFilter),
      )
    : players;

  return (
    <Window title="Player Panel" width={660} height={520} theme="admin">
      <Window.Content scrollable>
        <Section
          title={`Players (${filtered.length})`}
          buttons={
            check_antag_enabled && (
              <Button
                icon="crosshairs"
                onClick={() => act('check_antagonists')}
              >
                Check Antagonists
              </Button>
            )
          }
        >
          <Input
            fluid
            placeholder="Search by name, key, or job…"
            value={filter}
            onInput={(e, value) => setFilter(value)}
            mb={1}
          />
          <Table>
            <Table.Row header>
              <Table.Cell>Name / Real Name</Table.Cell>
              <Table.Cell>Key</Table.Cell>
              <Table.Cell>Job</Table.Cell>
            </Table.Row>
            {filtered.map((player) => (
              <>
                <Table.Row
                  key={player.ref}
                  style={{
                    cursor: 'pointer',
                    opacity: player.stat === 2 ? '0.55' : '1',
                    background:
                      expandedRef === player.ref
                        ? 'rgba(var(--color-fg-rgb, 138,200,255), 0.12)'
                        : undefined,
                  }}
                  onClick={() =>
                    setExpandedRef(
                      expandedRef === player.ref ? null : player.ref,
                    )
                  }
                >
                  <Table.Cell>
                    <Box bold>{player.name}</Box>
                    {player.real_name !== player.name && (
                      <Box color="label" fontSize="0.85em">
                        {player.real_name}
                      </Box>
                    )}
                  </Table.Cell>
                  <Table.Cell>{player.key}</Table.Cell>
                  <Table.Cell>
                    {player.job}
                    {player.stat === 2 && (
                      <Box inline color="bad" ml={0.5}>
                        [DEAD]
                      </Box>
                    )}
                  </Table.Cell>
                </Table.Row>
                {expandedRef === player.ref && (
                  <Table.Row key={`${player.ref}-actions`}>
                    <Table.Cell colSpan={3}>
                      <PlayerActions player={player} />
                    </Table.Cell>
                  </Table.Row>
                )}
              </>
            ))}
          </Table>
        </Section>
      </Window.Content>
    </Window>
  );
};

const PlayerActions = ({ player }: { readonly player: PlayerEntry }) => {
  const { act } = useBackend();
  return (
    <Box p={1} mb={0.5}>
      <Stack wrap>
        <Stack.Item>
          <Button
            icon="user-cog"
            onClick={() => act('player_panel', { ref: player.ref })}
          >
            PP
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="list"
            onClick={() => act('player_panel_extended', { ref: player.ref })}
          >
            PPE
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="sticky-note"
            onClick={() => act('show_notes', { ref: player.ref })}
          >
            Notes
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="eye"
            onClick={() => act('view_variables', { ref: player.ref })}
          >
            VV
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="comment"
            onClick={() => act('private_message', { key: player.key })}
          >
            PM
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="phone"
            onClick={() => act('subtle_message', { ref: player.ref })}
          >
            SM
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="map-marker-alt"
            onClick={() => act('jump_to', { ref: player.ref })}
          >
            JMP
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="exclamation-triangle"
            color="average"
            onClick={() => act('admin_alert', { ref: player.ref })}
          >
            ALERT
          </Button>
        </Stack.Item>
      </Stack>
      <Divider />
      <Box color="label" fontSize="0.8em">
        IP: {player.ip || '—'}
      </Box>
    </Box>
  );
};
