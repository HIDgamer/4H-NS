import { BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import { Button, LabeledList, NoticeBox, Section, Stack } from '../components';
import { Window } from '../layouts';

type Data = {
  has_co: BooleanLike;
  has_synth: BooleanLike;

  xeno_prefix: string;
  xeno_postfix: string;
  playtime_perks: BooleanLike;
  xeno_vision_level_pref: string;
  be_xeno_after_death: BooleanLike;
  be_agent: BooleanLike;

  commander_status: string;
  commander_sidearm: string;
  affiliation: string;

  synthetic_name: string;
  synthetic_type: string;
  synth_status: string;
};

export const WhitelistRoles = () => {
  const { act, data } = useBackend<Data>();
  const {
    has_co,
    has_synth,
    xeno_prefix,
    xeno_postfix,
    playtime_perks,
    xeno_vision_level_pref,
    be_xeno_after_death,
    be_agent,
    commander_status,
    commander_sidearm,
    affiliation,
    synthetic_name,
    synthetic_type,
    synth_status,
  } = data;

  return (
    <Window
      title="Whitelist Role Settings"
      theme="crtlobby"
      width={480}
      height={640}
    >
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Section title="Xenomorph">
              <LabeledList>
                <LabeledList.Item label="Xeno Prefix">
                  <Button onClick={() => act('xeno_prefix')}>
                    {xeno_prefix || '------'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Xeno Postfix">
                  <Button onClick={() => act('xeno_postfix')}>
                    {xeno_postfix || '------'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Enable Playtime Perks">
                  <Button
                    color={playtime_perks ? 'good' : 'bad'}
                    onClick={() => act('playtime_perks')}
                  >
                    {playtime_perks ? 'Yes' : 'No'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Default Night Vision">
                  <Button onClick={() => act('xeno_vision_level_pref')}>
                    {xeno_vision_level_pref}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Be Xenomorph After Unrevivable Death">
                  <Button
                    color={be_xeno_after_death ? 'good' : 'bad'}
                    onClick={() => act('be_special', { num: 1 })}
                  >
                    {be_xeno_after_death ? 'Yes' : 'No'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Be Agent">
                  <Button
                    color={be_agent ? 'good' : 'bad'}
                    onClick={() => act('be_special', { num: 0 })}
                  >
                    {be_agent ? 'Yes' : 'No'}
                  </Button>
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Commanding Officer">
              {has_co ? (
                <LabeledList>
                  <LabeledList.Item label="Whitelist Status">
                    <Button onClick={() => act('commander_status')}>
                      {commander_status}
                    </Button>
                  </LabeledList.Item>
                  <LabeledList.Item label="Sidearm">
                    <Button onClick={() => act('co_sidearm')}>
                      {commander_sidearm}
                    </Button>
                  </LabeledList.Item>
                  <LabeledList.Item label="Affiliation">
                    <Button onClick={() => act('co_affiliation')}>
                      {affiliation}
                    </Button>
                  </LabeledList.Item>
                </LabeledList>
              ) : (
                <NoticeBox>
                  You do not have the whitelist for this role.
                </NoticeBox>
              )}
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Synthetic">
              {has_synth ? (
                <LabeledList>
                  <LabeledList.Item label="Name">
                    <Button onClick={() => act('synth_name')}>
                      {synthetic_name}
                    </Button>
                  </LabeledList.Item>
                  <LabeledList.Item label="Type">
                    <Button onClick={() => act('synth_type')}>
                      {synthetic_type}
                    </Button>
                  </LabeledList.Item>
                  <LabeledList.Item label="Whitelist Status">
                    <Button onClick={() => act('synth_status')}>
                      {synth_status}
                    </Button>
                  </LabeledList.Item>
                </LabeledList>
              ) : (
                <NoticeBox>
                  You do not have the whitelist for this role.
                </NoticeBox>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
