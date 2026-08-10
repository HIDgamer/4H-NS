import { useBackend } from '../backend';
import { Box, Button, Section, Stack } from '../components';
import { Window } from '../layouts';

type Job = {
  title: string;
  disp_title: string;
  department: string;
  status: 'banned' | 'whitelisted' | 'timelocked' | 'available';
  slot_name?: string;
};

type Data = {
  jobs: Job[];
  ignore_on_start_join: boolean;
  ignore_on_late_join: boolean;
};

const STATUS_LABEL: Record<Job['status'], string> = {
  banned: 'BANNED',
  whitelisted: 'WHITELISTED',
  timelocked: 'TIMELOCKED',
  available: '',
};

// Same fixed department order as JobPreferences.tsx — kept in sync manually since the two
// interfaces don't share a components module of their own.
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

export const JobSlots = () => {
  const { act, data } = useBackend<Data>();
  const { jobs = [], ignore_on_start_join, ignore_on_late_join } = data;

  const groups = groupByDepartment(jobs);

  return (
    <Window
      title="Job Slot Assignment"
      theme="crtlobby"
      width={700}
      height={650}
    >
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Box color="label" fontSize="0.85rem">
              Assign a specific character slot to be used for each job, instead
              of your currently-loaded character.
            </Box>
          </Stack.Item>
          <Stack.Item>
            <Section
              title="Job Assignments"
              buttons={
                <Button icon="rotate-left" onClick={() => act('reset')}>
                  Reset
                </Button>
              }
            >
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
                          <Stack>
                            <Stack.Item
                              width="220px"
                              style={
                                job.status !== 'available'
                                  ? {
                                      textDecoration: 'line-through',
                                      opacity: '0.5',
                                    }
                                  : undefined
                              }
                            >
                              {job.disp_title}
                            </Stack.Item>
                            {job.status !== 'available' ? (
                              <Stack.Item color="bad">
                                {STATUS_LABEL[job.status]}
                              </Stack.Item>
                            ) : (
                              <Stack.Item>
                                <Button
                                  onClick={() =>
                                    act('assign', { title: job.title })
                                  }
                                >
                                  {job.slot_name}
                                </Button>
                              </Stack.Item>
                            )}
                          </Stack>
                        </Stack.Item>
                      ))}
                    </Stack>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              color={ignore_on_start_join ? 'bad' : 'good'}
              onClick={() => act('toggle_start_join')}
            >
              {ignore_on_start_join
                ? 'This preference is ignored when joining at the start of the round.'
                : 'This preference is used when joining at the start of the round.'}
            </Button>
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              color={ignore_on_late_join ? 'bad' : 'good'}
              onClick={() => act('toggle_late_join')}
            >
              {ignore_on_late_join
                ? 'This preference is ignored when joining a round in progress.'
                : 'This preference is used when joining a round in progress.'}
            </Button>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
