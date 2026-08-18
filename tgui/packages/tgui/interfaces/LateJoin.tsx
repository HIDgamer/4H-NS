import { useBackend } from '../backend';
import { Box, Button, Section, Stack } from '../components';
import { Window } from '../layouts';

type Job = {
  title: string;
  disp_title: string;
  department: string;
  current_positions: number;
  active: number;
};

type Data = {
  round_duration: string;
  evacuating: boolean;
  jobs: Job[];
};

// Kept in sync with JobPreferences.tsx/JobSlots.tsx's DEPARTMENT_ORDER by hand -
// the three interfaces don't share a components module of their own.
const DEPARTMENT_ORDER = [
  'Marines',
  'Command',
  'Auxiliary Support',
  'Military Police',
  'Engineering',
  'Requisition',
  'Medical',
  'Miscellaneous',
  'Weyland-Yutani',
  'Xenomorph',
  'Whitelisted',
  'Special',
  'Other',
];

const groupByDepartment = (jobs: Job[]) => {
  const groups = new Map<string, Job[]>();
  for (const job of jobs) {
    const list = groups.get(job.department) || [];
    list.push(job);
    groups.set(job.department, list);
  }
  return DEPARTMENT_ORDER.filter((dept) => groups.has(dept)).map((dept) => ({
    department: dept,
    jobs: groups.get(dept)!,
  }));
};

export const LateJoin = () => {
  const { act, data } = useBackend<Data>();
  const { round_duration, evacuating, jobs = [] } = data;
  const groups = groupByDepartment(jobs);

  return (
    <Window title="Late Join" theme="crtlobby" width={480} height={700}>
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Box color="label" fontSize="0.85rem">
              Round Duration: {round_duration}
            </Box>
            {evacuating && (
              <Box color="bad" bold fontSize="0.85rem">
                The Almayer is being evacuated.
              </Box>
            )}
          </Stack.Item>
          <Stack.Item>
            <Section title="Open Positions">
              <Stack vertical>
                {groups.map((group) => (
                  <Stack.Item key={group.department}>
                    <Box
                      bold
                      color="label"
                      fontSize="0.95rem"
                      mb={0.5}
                      style={{
                        borderBottom: '1px solid rgba(255, 255, 255, 0.15)',
                      }}
                    >
                      {group.department}
                    </Box>
                    <Stack vertical>
                      {group.jobs.map((job) => (
                        <Stack.Item key={job.title}>
                          <Button
                            fluid
                            style={{ textAlign: 'left' }}
                            onClick={() =>
                              act('select_job', { title: job.title })
                            }
                          >
                            {job.disp_title} ({job.current_positions}) (Active:{' '}
                            {job.active})
                          </Button>
                        </Stack.Item>
                      ))}
                    </Stack>
                  </Stack.Item>
                ))}
                {!groups.length && (
                  <Box color="label" italic>
                    No open positions available.
                  </Box>
                )}
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
