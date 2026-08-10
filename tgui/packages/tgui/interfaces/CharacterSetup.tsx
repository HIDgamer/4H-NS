import { BooleanLike } from 'common/react';
import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  Section,
  Stack,
} from '../components';
import { Window } from '../layouts';

type Data = {
  real_name: string;
  age: number;
  gender: 'Male' | 'Female';
  ethnicity: string;
  ethnicities: string[];
  preview_icon_b64: string;
  has_predator: BooleanLike;
  default_slot: number;
  random_name: BooleanLike;
  random_body: BooleanLike;
};

// The entry point replacing the legacy ShowChoices() popup. Covers the full Marine
// menu (appearance/loadout/traits, job preferences, job slots, background/records) plus the
// Xenomorph/CO/Synthetic/Predator whitelist role settings and Settings & Special. "Advanced
// Preferences (Legacy)" opens the old menu for anything not covered here yet; Mentor has no
// fields to migrate (legacy menu is a stub).
export const CharacterSetup = () => {
  const { act, data } = useBackend<Data>();
  const {
    real_name,
    age,
    gender,
    ethnicity,
    ethnicities = [],
    preview_icon_b64,
    has_predator,
    default_slot,
    random_name,
    random_body,
  } = data;

  const [nameDraft, setNameDraft] = useState(real_name);
  const [ageDraft, setAgeDraft] = useState(`${age}`);

  return (
    <Window title="Character Setup" theme="crtlobby" width={700} height={620}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Section>
              <Stack justify="center">
                <Stack.Item>
                  <Button icon="folder-open" onClick={() => act('load_slot')}>
                    Load Slot
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button icon="floppy-disk" onClick={() => act('save')}>
                    Save Slot
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button icon="rotate-left" onClick={() => act('reload')}>
                    Reload Slot
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Box color="label" fontSize="0.85rem">
                    Current slot: {default_slot}
                  </Box>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item width="160px">
                <Section title="Preview" fill>
                  <Stack vertical align="center">
                    <Stack.Item>
                      <Box
                        width="128px"
                        height="128px"
                        style={{ overflow: 'hidden', textAlign: 'center' }}
                      >
                        {preview_icon_b64 ? (
                          <img
                            src={`data:image/png;base64,${preview_icon_b64}`}
                            style={{
                              imageRendering: 'pixelated',
                              transform: 'scale(2.5)',
                              transformOrigin: 'top center',
                              marginTop: '12px',
                            }}
                          />
                        ) : (
                          <Box color="label" mt={4}>
                            No preview yet.
                          </Box>
                        )}
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Box
                        style={{
                          display: 'flex',
                          justifyContent: 'center',
                          gap: '4px',
                        }}
                      >
                        <Button
                          icon="rotate-left"
                          tooltip="Rotate Left"
                          onClick={() =>
                            act('rotate_preview', { clockwise: false })
                          }
                        />
                        <Button
                          icon="rotate-right"
                          tooltip="Rotate Right"
                          onClick={() =>
                            act('rotate_preview', { clockwise: true })
                          }
                        />
                      </Box>
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item grow>
                <Section title="Profile">
                  <LabeledList>
                    <LabeledList.Item label="Name">
                      <Input
                        fluid
                        value={nameDraft}
                        onChange={(e, value) => {
                          setNameDraft(value);
                          act('name', { name: value });
                        }}
                      />
                    </LabeledList.Item>
                    <LabeledList.Item label="Age">
                      <Input
                        width="4em"
                        value={ageDraft}
                        onChange={(e, value) => {
                          setAgeDraft(value);
                          act('age', { age: value });
                        }}
                      />
                    </LabeledList.Item>
                    <LabeledList.Item label="Gender">
                      <Button onClick={() => act('gender')}>{gender}</Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Ethnicity">
                      <Dropdown
                        selected={ethnicity}
                        options={ethnicities}
                        onSelected={(value) =>
                          act('ethnicity', { ethnicity: value })
                        }
                      />
                    </LabeledList.Item>
                    <LabeledList.Item label="Always Random Name">
                      <Button
                        color={random_name ? 'good' : 'bad'}
                        onClick={() => act('random_name')}
                      >
                        {random_name ? 'Yes' : 'No'}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Always Random Appearance">
                      <Button
                        color={random_body ? 'good' : 'bad'}
                        onClick={() => act('random_body')}
                      >
                        {random_body ? 'Yes' : 'No'}
                      </Button>
                    </LabeledList.Item>
                  </LabeledList>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Section title="Appearance & Loadout">
              <Stack wrap>
                <Stack.Item grow basis="45%">
                  <Button fluid icon="user" onClick={() => act('open_hair')}>
                    Hair & Facial Hair
                  </Button>
                </Stack.Item>
                <Stack.Item grow basis="45%">
                  <Button fluid icon="child" onClick={() => act('open_body')}>
                    Body & Skin Color
                  </Button>
                </Stack.Item>
                <Stack.Item grow basis="45%">
                  <Button fluid icon="star" onClick={() => act('open_traits')}>
                    Character Traits
                  </Button>
                </Stack.Item>
                <Stack.Item grow basis="45%">
                  <Button
                    fluid
                    icon="shirt"
                    onClick={() => act('open_loadout')}
                  >
                    Starting Loadout
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Jobs & Background">
              <Stack wrap>
                <Stack.Item grow basis="45%">
                  <Button
                    fluid
                    icon="list-check"
                    onClick={() => act('open_job_prefs')}
                  >
                    Job Preferences
                  </Button>
                </Stack.Item>
                <Stack.Item grow basis="45%">
                  <Button
                    fluid
                    icon="id-badge"
                    onClick={() => act('open_job_slots')}
                  >
                    Job Slot Assignment
                  </Button>
                </Stack.Item>
                <Stack.Item grow basis="45%">
                  <Button
                    fluid
                    icon="file-lines"
                    onClick={() => act('open_background')}
                  >
                    Background & Records
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Role Settings">
              <Stack wrap>
                <Stack.Item grow basis="45%">
                  <Button
                    fluid
                    icon="dna"
                    onClick={() => act('open_whitelist_roles')}
                  >
                    Xeno / CO / Synthetic Settings
                  </Button>
                </Stack.Item>
                {!!has_predator && (
                  <Stack.Item grow basis="45%">
                    <Button
                      fluid
                      icon="user-ninja"
                      onClick={() => act('open_predator')}
                    >
                      Predator Settings
                    </Button>
                  </Stack.Item>
                )}
                <Stack.Item grow basis="45%">
                  <Button
                    fluid
                    icon="sliders"
                    onClick={() => act('open_settings')}
                  >
                    Settings & Special
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              color="transparent"
              icon="ellipsis"
              onClick={() => act('open_legacy')}
            >
              Advanced Preferences (Legacy)
            </Button>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
