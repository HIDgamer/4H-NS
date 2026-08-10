import { BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import { Button, LabeledList, Section, Stack } from '../components';
import { Window } from '../layouts';

type Data = {
  origin: string;
  religion: string;
  nanotrasen_relation: string;
  preferred_squad: string;
  underwear: string;
  undershirt: string;
  backbag: string;
  preferred_armor: string;
  show_job_gear: BooleanLike;
  bg_state: string;
  med_record: string;
  gen_record: string;
  sec_record: string;
  flavor_text: string;
};

export const BackgroundSetup = () => {
  const { act, data } = useBackend<Data>();
  const {
    origin,
    religion,
    nanotrasen_relation,
    preferred_squad,
    underwear,
    undershirt,
    backbag,
    preferred_armor,
    show_job_gear,
    med_record,
    gen_record,
    sec_record,
    flavor_text,
  } = data;

  return (
    <Window
      title="Background & Records"
      theme="crtlobby"
      width={480}
      height={640}
    >
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Section title="Background">
              <LabeledList>
                <LabeledList.Item label="Origin">
                  <Button onClick={() => act('origin')}>{origin}</Button>
                </LabeledList.Item>
                <LabeledList.Item label="Religion">
                  <Button onClick={() => act('religion')}>{religion}</Button>
                </LabeledList.Item>
                <LabeledList.Item label="Corporate Relation">
                  <Button onClick={() => act('nt_relation')}>
                    {nanotrasen_relation}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Preferred Squad">
                  <Button onClick={() => act('prefsquad')}>
                    {preferred_squad}
                  </Button>
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Gear Options">
              <LabeledList>
                <LabeledList.Item label="Underwear">
                  <Button onClick={() => act('underwear')}>{underwear}</Button>
                </LabeledList.Item>
                <LabeledList.Item label="Undershirt">
                  <Button onClick={() => act('undershirt')}>
                    {undershirt}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Backpack">
                  <Button onClick={() => act('bag')}>{backbag}</Button>
                </LabeledList.Item>
                <LabeledList.Item label="Preferred Armor">
                  <Button onClick={() => act('prefarmor')}>
                    {preferred_armor}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Show Job Gear on Preview">
                  <Button
                    color={show_job_gear ? 'good' : 'bad'}
                    onClick={() => act('toggle_job_gear')}
                  >
                    {show_job_gear ? 'On' : 'Off'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Preview Background">
                  <Button onClick={() => act('cycle_bg')}>Cycle</Button>
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Records & Flavor Text">
              <LabeledList>
                <LabeledList.Item label="Medical Records">
                  <Button onClick={() => act('med_record')}>
                    {med_record ? 'Edit' : 'Set'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Employment Records">
                  <Button onClick={() => act('gen_record')}>
                    {gen_record ? 'Edit' : 'Set'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Security Records">
                  <Button onClick={() => act('sec_record')}>
                    {sec_record ? 'Edit' : 'Set'}
                  </Button>
                </LabeledList.Item>
                <LabeledList.Item label="Flavor Text">
                  <Button onClick={() => act('flavor_text')}>
                    {flavor_text ? 'Edit' : 'Set'}
                  </Button>
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
