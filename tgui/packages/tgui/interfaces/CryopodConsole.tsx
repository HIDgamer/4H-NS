import { useBackend } from '../backend';
import { Box, Button, Section, Stack } from '../components';
import { Window } from '../layouts';

type Data = {
  welcome_name: string;
  cryotype: string;
  frozen_crew: string[];
  frozen_items: string[];
};

export const CryopodConsole = (props) => {
  const { act, data } = useBackend<Data>();
  const { welcome_name, cryotype, frozen_crew = [], frozen_items = [] } = data;

  return (
    <Window
      title={`Cryogenic Oversight Control — ${cryotype}`}
      width={420}
      height={480}
    >
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Box color="label" italic>
              Welcome, {welcome_name}.
            </Box>
          </Stack.Item>

          <Stack.Item>
            <Section title="Recovery">
              <Stack>
                <Stack.Item grow>
                  <Button
                    fluid
                    icon="box-open"
                    disabled={frozen_items.length === 0}
                    onClick={() => act('recover_item')}
                  >
                    Recover Object
                  </Button>
                </Stack.Item>
                <Stack.Item grow>
                  <Button.Confirm
                    fluid
                    icon="boxes-stacked"
                    disabled={frozen_items.length === 0}
                    onClick={() => act('recover_all')}
                  >
                    Recover All Objects
                  </Button.Confirm>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section title="Recently Stored Crewmembers" fill>
              {frozen_crew.length === 0 ? (
                <Box color="label" italic>
                  No records.
                </Box>
              ) : (
                frozen_crew.map((person, i) => <Box key={i}>{person}</Box>)
              )}
            </Section>
          </Stack.Item>

          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section title="Stored Objects" fill>
              {frozen_items.length === 0 ? (
                <Box color="label" italic>
                  Nothing in storage.
                </Box>
              ) : (
                frozen_items.map((item, i) => <Box key={i}>{item}</Box>)
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
