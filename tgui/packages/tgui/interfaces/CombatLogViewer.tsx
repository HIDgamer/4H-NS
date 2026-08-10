import { useBackend } from '../backend';
import { Box, Section } from '../components';
import { Window } from '../layouts';

type Data = {
  target_name: string;
  logs: string[];
};

export const CombatLogViewer = (props) => {
  const { data } = useBackend<Data>();
  const { target_name, logs = [] } = data;

  return (
    <Window
      title={`Combat Logs: ${target_name}`}
      width={600}
      height={480}
      theme="admin"
    >
      <Window.Content scrollable>
        <Section fill>
          {logs.length === 0 ? (
            <Box color="label" italic>
              No combat log entries.
            </Box>
          ) : (
            logs.map((entry, i) => (
              // eslint-disable-next-line react/no-danger
              <Box
                key={i}
                mb={0.25}
                dangerouslySetInnerHTML={{ __html: entry }}
              />
            ))
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
