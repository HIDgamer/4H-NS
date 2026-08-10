import { useBackend } from '../backend';
import { Box, Button, Section, Stack } from '../components';
import { Window } from '../layouts';

type Job = {
  title: string;
  disp_title: string;
  department: string;
  status: 'banned' | 'whitelisted' | 'timelocked' | 'available';
  priority?: number;
  special_option?: string;
};

type Data = {
  jobs: Job[];
  alternate_option: number;
};

// Fixed display order for department headers — jobs.dm's GLOB.ROLES_* lists (which
// get_job_department() in role_authority.dm classifies against) have no inherent ordering of
// their own, so this is purely presentational.
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

const PRIORITIES = [
  { value: 0, label: 'NEVER', color: 'red' },
  { value: 1, label: 'HIGH', color: 'blue' },
  { value: 2, label: 'MEDIUM', color: 'green' },
  { value: 3, label: 'LOW', color: 'orange' },
] as const;

const ALTERNATE_OPTIONS = [
  {
    value: 0,
    label: 'Get random job if preferences unavailable',
    color: 'green',
  },
  { value: 1, label: 'Be marine if preference unavailable', color: 'red' },
  {
    value: 2,
    label: 'Return to lobby if preference unavailable',
    color: 'purple',
  },
  {
    value: 3,
    label: 'Be Xenomorph if preference unavailable',
    color: 'orange',
  },
];

const STATUS_LABEL: Record<Job['status'], string> = {
  banned: 'BANNED',
  whitelisted: 'WHITELISTED',
  timelocked: 'TIMELOCKED',
  available: '',
};

export const JobPreferences = () => {
  const { act, data } = useBackend<Data>();
  const { jobs = [], alternate_option } = data;

  const currentAlternate = ALTERNATE_OPTIONS.find(
    (o) => o.value === alternate_option,
  );
  const groups = groupByDepartment(jobs);

  return (
    <Window title="Job Preferences" theme="crtlobby" width={800} height={700}>
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Box color="label" fontSize="0.85rem">
              Choose occupation chances. Unavailable occupations are crossed
              out.
            </Box>
          </Stack.Item>
          <Stack.Item>
            <Section
              title="Occupations"
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
                              <>
                                {job.special_option && (
                                  <Stack.Item>
                                    <Button
                                      onClick={() =>
                                        act('special_option', {
                                          title: job.title,
                                        })
                                      }
                                    >
                                      {job.special_option}
                                    </Button>
                                  </Stack.Item>
                                )}
                                <Stack.Item grow>
                                  <Stack>
                                    {PRIORITIES.map((p) => (
                                      <Stack.Item key={p.value}>
                                        <Button
                                          color={
                                            job.priority === p.value
                                              ? p.color
                                              : 'transparent'
                                          }
                                          onClick={() =>
                                            act('set_priority', {
                                              title: job.title,
                                              priority: p.value,
                                            })
                                          }
                                        >
                                          {p.label}
                                        </Button>
                                      </Stack.Item>
                                    ))}
                                  </Stack>
                                </Stack.Item>
                              </>
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
            <Section title="If No Preferred Job Is Available">
              <Stack wrap>
                {ALTERNATE_OPTIONS.map((o) => (
                  <Stack.Item key={o.value}>
                    <Button
                      color={
                        o.value === alternate_option ? o.color : 'transparent'
                      }
                      onClick={() =>
                        act('alternate_option', { value: o.value })
                      }
                    >
                      {o.label}
                    </Button>
                  </Stack.Item>
                ))}
              </Stack>
              {currentAlternate && (
                <Box mt={1} color="label" fontSize="0.85rem">
                  Currently: {currentAlternate.label}
                </Box>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
