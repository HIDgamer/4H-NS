import { useBackend } from '../backend';
import { Box, Section, Stack, Table, Tabs } from '../components';
import { Window } from '../layouts';

type StatRow = Record<string, unknown>;

type Data = {
  menu: string;
  subMenu: string;
  dataMenu: string;
  current_time: string;
  round?: StatRow;
  human?: StatRow;
  xeno?: StatRow;
};

// ─── Generic, data-driven rendering ────────────────────────────────────────
// The DM side sends fairly uniform shapes throughout this whole panel
// (flat scalar objects, or arrays of {name, value}/richer flat objects), so
// rather than hand-writing bespoke layouts for a dozen-plus stat categories,
// these two components introspect whatever's actually in the data and
// render it — new stat categories added on the DM side show up here without
// any frontend changes needed.

const formatLabel = (key: string) =>
  key.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

const isPrimitive = (value: unknown) =>
  value === null ||
  value === undefined ||
  typeof value === 'string' ||
  typeof value === 'number' ||
  typeof value === 'boolean';

/** Renders a single flat stat object (e.g. round overview, per-faction totals) as a key/value grid. */
const StatSummary = (props: { readonly data?: StatRow }) => {
  const { data } = props;
  if (!data) {
    return (
      <Box color="label" italic>
        No data available.
      </Box>
    );
  }
  const entries = Object.entries(data).filter(([, v]) => isPrimitive(v));
  if (entries.length === 0) {
    return (
      <Box color="label" italic>
        Nothing to show here.
      </Box>
    );
  }
  return (
    <Table>
      {entries.map(([key, value]) => (
        <Table.Row key={key}>
          <Table.Cell color="label" width="60%">
            {formatLabel(key)}
          </Table.Cell>
          <Table.Cell bold>{String(value ?? '—')}</Table.Cell>
        </Table.Row>
      ))}
    </Table>
  );
};

/** Renders an array of stat rows as a table, auto-deriving columns from primitive fields on the first row. */
const StatTable = (props: {
  readonly rows?: StatRow[];
  readonly sortByValue?: boolean;
}) => {
  const { rows, sortByValue } = props;
  if (!rows || rows.length === 0) {
    return (
      <Box color="label" italic>
        No entries.
      </Box>
    );
  }
  const columns = Object.keys(rows[0]).filter((key) =>
    isPrimitive(rows[0][key]),
  );
  const sortedRows = sortByValue
    ? [...rows].sort((a, b) => (Number(b.value) || 0) - (Number(a.value) || 0))
    : rows;
  return (
    <Table>
      <Table.Row header>
        {columns.map((key) => (
          <Table.Cell key={key} color="label">
            {formatLabel(key)}
          </Table.Cell>
        ))}
      </Table.Row>
      {sortedRows.map((row, i) => (
        <Table.Row key={i}>
          {columns.map((key) => (
            <Table.Cell key={key}>{String(row[key] ?? '—')}</Table.Cell>
          ))}
        </Table.Row>
      ))}
    </Table>
  );
};

// ─── Navigation ─────────────────────────────────────────────────────────────

const GLOBAL_TABS = [
  { id: 'general', label: 'General' },
  { id: 'participants', label: 'Participants' },
  { id: 'deaths', label: 'Deaths' },
  { id: 'jobs', label: 'Jobs' },
  { id: 'castes', label: 'Castes' },
  { id: 'weapons', label: 'Weapons' },
];

const HUMAN_TABS = [
  { id: 'general', label: 'General' },
  { id: 'deaths', label: 'Deaths' },
  { id: 'weapons', label: 'Weapons' },
  { id: 'roles', label: 'Roles' },
  { id: 'medals', label: 'Medals' },
];

const XENO_TABS = [
  { id: 'general', label: 'General' },
  { id: 'deaths', label: 'Deaths' },
  { id: 'castes', label: 'Castes' },
  { id: 'medals', label: 'Medals' },
];

const GlobalPanel = (props: {
  readonly category: string;
  readonly round?: StatRow;
}) => {
  const { category, round } = props;
  switch (category) {
    case 'participants':
      return (
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Participants">
              <StatTable rows={round?.participants as StatRow[]} sortByValue />
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Hijack Participants">
              <StatTable
                rows={round?.hijack_participants as StatRow[]}
                sortByValue
              />
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Final Participants">
              <StatTable
                rows={round?.final_participants as StatRow[]}
                sortByValue
              />
            </Section>
          </Stack.Item>
        </Stack>
      );
    case 'deaths':
      return (
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Deaths by Cause">
              <StatTable rows={round?.total_deaths as StatRow[]} sortByValue />
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Recent Deaths">
              <StatTable rows={round?.death_stats_list as StatRow[]} />
            </Section>
          </Stack.Item>
        </Stack>
      );
    case 'jobs':
      return (
        <Section title="Job Stats">
          <StatTable rows={round?.job_stats_list as StatRow[]} />
        </Section>
      );
    case 'castes':
      return (
        <Section title="Caste Stats">
          <StatTable rows={round?.caste_stats_list as StatRow[]} />
        </Section>
      );
    case 'weapons':
      return (
        <Section title="Weapon Stats">
          <StatTable rows={round?.weapon_stats_list as StatRow[]} />
        </Section>
      );
    default:
      return (
        <Section title="Round Overview">
          <StatSummary data={round} />
        </Section>
      );
  }
};

const PersonalPanel = (props: {
  readonly subMenu: string;
  readonly dataMenu: string;
  readonly human?: StatRow;
  readonly xeno?: StatRow;
}) => {
  const { subMenu, dataMenu, human, xeno } = props;
  const faction = subMenu === 'xeno' ? xeno : human;

  switch (dataMenu) {
    case 'deaths':
      return (
        <Section title="Deaths">
          <StatTable rows={faction?.death_list as StatRow[]} />
        </Section>
      );
    case 'weapons':
      return (
        <Section title="Weapons Used">
          <StatTable rows={faction?.weapon_stats_list as StatRow[]} />
        </Section>
      );
    case 'castes':
      return (
        <Section title="Castes Played">
          <StatTable rows={faction?.caste_stats_list as StatRow[]} />
        </Section>
      );
    case 'roles':
      return (
        <Section title="Roles Played">
          <StatTable rows={faction?.job_stats_list as StatRow[]} />
        </Section>
      );
    case 'medals':
      return (
        <Section title="Medals">
          <StatTable rows={faction?.medal_list as StatRow[]} />
        </Section>
      );
    default:
      return (
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Overview">
              <StatSummary data={faction} />
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Humans Killed">
              <StatTable
                rows={faction?.humans_killed as StatRow[]}
                sortByValue
              />
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Xenos Killed">
              <StatTable
                rows={faction?.xenos_killed as StatRow[]}
                sortByValue
              />
            </Section>
          </Stack.Item>
        </Stack>
      );
  }
};

export const StatisticsPanel = (props) => {
  const { act, data } = useBackend<Data>();
  const { menu, subMenu, dataMenu, current_time, round, human, xeno } = data;

  const subTabs =
    menu === 'personal'
      ? subMenu === 'xeno'
        ? XENO_TABS
        : HUMAN_TABS
      : GLOBAL_TABS;

  return (
    <Window title="Statistics" width={560} height={620}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Tabs>
              <Tabs.Tab
                selected={menu === 'global'}
                onClick={() => act('set_menu', { menu: 'global' })}
              >
                Global
              </Tabs.Tab>
              <Tabs.Tab
                selected={menu === 'personal'}
                onClick={() => act('set_menu', { menu: 'personal' })}
              >
                Personal
              </Tabs.Tab>
              <Box
                position="absolute"
                right="0.5rem"
                color="label"
                fontSize="0.8rem"
                mt="0.4rem"
              >
                {current_time}
              </Box>
            </Tabs>
          </Stack.Item>

          {menu === 'personal' && (
            <Stack.Item>
              <Tabs>
                <Tabs.Tab
                  selected={subMenu === 'human'}
                  onClick={() => act('set_submenu', { submenu: 'human' })}
                >
                  Human
                </Tabs.Tab>
                <Tabs.Tab
                  selected={subMenu === 'xeno'}
                  onClick={() => act('set_submenu', { submenu: 'xeno' })}
                >
                  Xeno
                </Tabs.Tab>
              </Tabs>
            </Stack.Item>
          )}

          <Stack.Item>
            <Tabs>
              {subTabs.map((tab) => {
                const stateKey =
                  menu === 'global' ? 'set_submenu' : 'set_datamenu';
                const paramKey = menu === 'global' ? 'submenu' : 'datamenu';
                const active = menu === 'global' ? subMenu : dataMenu;
                return (
                  <Tabs.Tab
                    key={tab.id}
                    selected={active === tab.id}
                    onClick={() => act(stateKey, { [paramKey]: tab.id })}
                  >
                    {tab.label}
                  </Tabs.Tab>
                );
              })}
            </Tabs>
          </Stack.Item>

          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            {menu === 'personal' ? (
              <PersonalPanel
                subMenu={subMenu}
                dataMenu={dataMenu}
                human={human}
                xeno={xeno}
              />
            ) : (
              <GlobalPanel category={subMenu} round={round} />
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
