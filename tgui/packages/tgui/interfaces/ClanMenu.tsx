import { useBackend } from '../backend';
import { Box, Button, Section, Stack, Table } from '../components';
import { Window } from '../layouts';

type ClanMember = {
  player_id: string;
  name: string;
  rank: string;
  rank_pos: number;
  honor: number;
};

type Data = {
  clan_id: string | null;
  clan_name: string;
  clan_description: string;
  clan_honor: number | null;
  clan_keys: ClanMember[];
  player_rank_pos: number;
  player_delete_clan: boolean;
  player_sethonor_clan: boolean;
  player_setcolor_clan: boolean;
  player_rename_clan: boolean;
  player_setdesc_clan: boolean;
  player_modify_ranks: boolean;
  player_purge: boolean;
  player_move_clans: boolean;
  can_change_view: boolean;
};

export const ClanMenu = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    clan_id,
    clan_name,
    clan_description,
    clan_honor,
    clan_keys = [],
    player_rank_pos,
    player_delete_clan,
    player_sethonor_clan,
    player_setcolor_clan,
    player_rename_clan,
    player_setdesc_clan,
    player_modify_ranks,
    player_purge,
    player_move_clans,
    can_change_view,
  } = data;

  const hasClan = !!clan_id;

  return (
    <Window title="Clan Menu" width={550} height={550}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Section
              title={clan_name}
              buttons={
                can_change_view && (
                  <Button icon="right-left" onClick={() => act('choose_clan')}>
                    Change View
                  </Button>
                )
              }
            >
              <Box color="label" mb={1}>
                {clan_description}
              </Box>
              {hasClan && (
                <Box>
                  Honor: <b>{clan_honor}</b>
                </Box>
              )}
              {hasClan && (
                <Stack mt={1}>
                  {player_rename_clan && (
                    <Stack.Item>
                      <Button
                        icon="pen"
                        onClick={() => act('rename', { clan_id })}
                      >
                        Rename
                      </Button>
                    </Stack.Item>
                  )}
                  {player_setdesc_clan && (
                    <Stack.Item>
                      <Button
                        icon="align-left"
                        onClick={() => act('setdesc', { clan_id })}
                      >
                        Set Description
                      </Button>
                    </Stack.Item>
                  )}
                  {player_setcolor_clan && (
                    <Stack.Item>
                      <Button
                        icon="palette"
                        onClick={() => act('setcolor', { clan_id })}
                      >
                        Set Color
                      </Button>
                    </Stack.Item>
                  )}
                  {player_sethonor_clan && (
                    <Stack.Item>
                      <Button
                        icon="star"
                        onClick={() => act('sethonor', { clan_id })}
                      >
                        Set Honor
                      </Button>
                    </Stack.Item>
                  )}
                  {player_delete_clan && (
                    <Stack.Item>
                      <Button.Confirm
                        icon="trash"
                        color="bad"
                        onClick={() => act('delete', { clan_id })}
                      >
                        Delete Clan
                      </Button.Confirm>
                    </Stack.Item>
                  )}
                </Stack>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section title="Members" fill>
              {clan_keys.length === 0 ? (
                <Box color="label" italic>
                  No members.
                </Box>
              ) : (
                <Table>
                  <Table.Row header>
                    <Table.Cell color="label">Name</Table.Cell>
                    <Table.Cell color="label">Rank</Table.Cell>
                    <Table.Cell color="label">Honor</Table.Cell>
                    {(player_purge ||
                      player_move_clans ||
                      player_modify_ranks) && (
                      <Table.Cell color="label">Actions</Table.Cell>
                    )}
                  </Table.Row>
                  {clan_keys.map((member) => {
                    // Mirrors the server-side targeting check (client.dm ui_act) —
                    // hide action buttons for members the actor can't legally act
                    // on anyway, rather than showing controls that always fail.
                    const canTarget = player_rank_pos > member.rank_pos;
                    return (
                      <Table.Row key={member.player_id}>
                        <Table.Cell>{member.name}</Table.Cell>
                        <Table.Cell>{member.rank}</Table.Cell>
                        <Table.Cell>{member.honor}</Table.Cell>
                        {(player_purge ||
                          player_move_clans ||
                          player_modify_ranks) && (
                          <Table.Cell>
                            {canTarget && (
                              <Stack>
                                {player_modify_ranks && (
                                  <Stack.Item>
                                    <Button
                                      icon="arrow-up-9-1"
                                      tooltip="Change Rank"
                                      onClick={() =>
                                        act('modifyrank', {
                                          target_ref: member.player_id,
                                        })
                                      }
                                    />
                                  </Stack.Item>
                                )}
                                {player_move_clans && (
                                  <Stack.Item>
                                    <Button
                                      icon="right-left"
                                      tooltip="Move to Clan"
                                      onClick={() =>
                                        act('moveclan', {
                                          target_ref: member.player_id,
                                        })
                                      }
                                    />
                                  </Stack.Item>
                                )}
                                {player_purge && (
                                  <Stack.Item>
                                    <Button.Confirm
                                      icon="trash"
                                      color="bad"
                                      tooltip="Purge Profile"
                                      onClick={() =>
                                        act('purge', {
                                          target_ref: member.player_id,
                                        })
                                      }
                                    />
                                  </Stack.Item>
                                )}
                              </Stack>
                            )}
                          </Table.Cell>
                        )}
                      </Table.Row>
                    );
                  })}
                </Table>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
