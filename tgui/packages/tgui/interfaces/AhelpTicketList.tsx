import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Section, Stack, Tabs } from '../components';
import { Window } from '../layouts';

type TicketSummary = {
  ref: string;
  id: number;
  name: string;
  initiator: string;
  marked_admin: string | null;
  disconnected: boolean;
};

type Data = {
  active_tickets: TicketSummary[];
  closed_tickets: TicketSummary[];
  resolved_tickets: TicketSummary[];
  // Sent once via ui_static_data() — reflects which statclick opened the window.
  initial_tab: 'active' | 'closed' | 'resolved';
};

const TABS = [
  { id: 'active' as const, label: 'Active', key: 'active_tickets' as const },
  { id: 'closed' as const, label: 'Closed', key: 'closed_tickets' as const },
  {
    id: 'resolved' as const,
    label: 'Resolved',
    key: 'resolved_tickets' as const,
  },
];

export const AhelpTicketList = (props) => {
  const { act, data } = useBackend<Data>();
  const [tab, setTab] = useState(data.initial_tab || 'active');

  const activeTab = TABS.find((t) => t.id === tab) ?? TABS[0];
  const tickets = data[activeTab.key] ?? [];

  return (
    <Window title="Adminhelp Tickets" width={520} height={480} theme="admin">
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Tabs>
              {TABS.map((t) => (
                <Tabs.Tab
                  key={t.id}
                  selected={tab === t.id}
                  onClick={() => setTab(t.id)}
                  rightSlot={
                    <Box className="Tab__right" opacity={0.7}>
                      {(data[t.key] ?? []).length}
                    </Box>
                  }
                >
                  {t.label}
                </Tabs.Tab>
              ))}
            </Tabs>
          </Stack.Item>
          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section fill>
              {tickets.length === 0 ? (
                <Box color="label" italic>
                  No {activeTab.label.toLowerCase()} tickets.
                </Box>
              ) : (
                tickets.map((ticket) => (
                  <Button
                    key={ticket.ref}
                    fluid
                    mb={0.5}
                    color={ticket.disconnected ? 'average' : undefined}
                    onClick={() =>
                      act('open_ticket', { ticket_ref: ticket.ref })
                    }
                  >
                    <Stack>
                      <Stack.Item>#{ticket.id}</Stack.Item>
                      <Stack.Item grow>
                        {ticket.initiator}: {ticket.name}
                      </Stack.Item>
                      {ticket.disconnected && (
                        <Stack.Item color="average">DC</Stack.Item>
                      )}
                      {!!ticket.marked_admin && (
                        <Stack.Item color="good">
                          {ticket.marked_admin}
                        </Stack.Item>
                      )}
                    </Stack>
                  </Button>
                ))
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
