import { useBackend } from '../backend';
import { Box, Button, Section, Stack } from '../components';
import { Window } from '../layouts';

// Mirrors code/__DEFINES/admin.dm
const AHELP_ACTIVE = 1;
const AHELP_CLOSED = 2;
const AHELP_RESOLVED = 3;

type RelatedTicket = {
  ref: string;
  id: number;
  name: string;
  state: number;
};

type Data = {
  id: number;
  ticket_name: string;
  state: number;
  is_staff: boolean;
  opened_at: string;
  opened_ago: string;
  closed_at?: string;
  closed_ago?: string;
  initiator_name?: string;
  disconnected?: boolean;
  marked_admin?: string | null;
  related_tickets?: RelatedTicket[];
  interactions: string[];
};

const STATE_LABEL: Record<number, string> = {
  [AHELP_ACTIVE]: 'OPEN',
  [AHELP_CLOSED]: 'CLOSED',
  [AHELP_RESOLVED]: 'RESOLVED',
};

const STATE_COLOR: Record<number, string> = {
  [AHELP_ACTIVE]: 'bad',
  [AHELP_CLOSED]: 'label',
  [AHELP_RESOLVED]: 'good',
};

const InteractionLog = (props: { readonly interactions: string[] }) => {
  const { interactions } = props;
  return (
    <Section title="Log" fill scrollable>
      {interactions.length === 0 ? (
        <Box color="label" italic>
          No activity yet.
        </Box>
      ) : (
        interactions.map((line, i) => (
          <Box
            key={i}
            mb={0.5}
            // Lines come pre-formatted with color/emphasis markup from the DM side.
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{ __html: line }}
          />
        ))
      )}
    </Section>
  );
};

export const AhelpTicket = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    id,
    ticket_name,
    state,
    is_staff,
    opened_at,
    opened_ago,
    closed_at,
    closed_ago,
    initiator_name,
    disconnected,
    marked_admin,
    related_tickets = [],
    interactions = [],
  } = data;

  return (
    <Window title={`Ticket #${id}`} width={480} height={560} theme="admin">
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Section>
              <Stack>
                <Stack.Item grow>{ticket_name}</Stack.Item>
                <Stack.Item color={STATE_COLOR[state]} bold>
                  {STATE_LABEL[state] ?? 'UNKNOWN'}
                </Stack.Item>
              </Stack>
              <Box color="label" italic>
                Opened {opened_at} ({opened_ago} ago)
              </Box>
              {!!closed_at && (
                <Box color="label" italic>
                  Closed {closed_at} ({closed_ago} ago)
                </Box>
              )}
              {is_staff && (
                <>
                  <Box>
                    Initiator: {initiator_name}
                    {disconnected && (
                      <Box as="span" color="average" ml={1}>
                        (disconnected)
                      </Box>
                    )}
                  </Box>
                  <Box>
                    Marked by:{' '}
                    {marked_admin || (
                      <Box as="span" color="label" italic>
                        nobody
                      </Box>
                    )}
                  </Box>
                </>
              )}
            </Section>
          </Stack.Item>

          {is_staff && (
            <Stack.Item>
              <Section title="Actions">
                <Stack wrap>
                  <Stack.Item>
                    <Button icon="pen" onClick={() => act('retitle')}>
                      Retitle
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button icon="bookmark" onClick={() => act('mark')}>
                      Mark/Unmark
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="reply"
                      disabled={state !== AHELP_ACTIVE}
                      onClick={() => act('reply')}
                    >
                      Reply
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="comment-dots"
                      disabled={state !== AHELP_ACTIVE}
                      onClick={() => act('autoreply')}
                    >
                      AutoReply
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button.Confirm
                      icon="ban"
                      disabled={state !== AHELP_ACTIVE}
                      onClick={() => act('reject')}
                    >
                      Reject
                    </Button.Confirm>
                  </Stack.Item>
                  <Stack.Item>
                    <Button.Confirm
                      icon="times"
                      disabled={state !== AHELP_ACTIVE}
                      onClick={() => act('close')}
                    >
                      Close
                    </Button.Confirm>
                  </Stack.Item>
                  <Stack.Item>
                    <Button.Confirm
                      icon="check"
                      color="good"
                      disabled={state !== AHELP_ACTIVE}
                      onClick={() => act('resolve')}
                    >
                      Resolve
                    </Button.Confirm>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="arrow-rotate-left"
                      disabled={state === AHELP_ACTIVE}
                      onClick={() => act('reopen')}
                    >
                      Reopen
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button.Confirm
                      icon="user-graduate"
                      disabled={state !== AHELP_ACTIVE}
                      onClick={() => act('defer')}
                    >
                      Defer to Mentors
                    </Button.Confirm>
                  </Stack.Item>
                </Stack>
              </Section>
            </Stack.Item>
          )}

          {is_staff && related_tickets.length > 0 && (
            <Stack.Item>
              <Section title="Other Tickets From This Player">
                {related_tickets.map((ticket) => (
                  <Button
                    key={ticket.ref}
                    fluid
                    mb={0.5}
                    color={STATE_COLOR[ticket.state]}
                    onClick={() =>
                      act('open_ticket', { ticket_ref: ticket.ref })
                    }
                  >
                    #{ticket.id}: {ticket.name} ({STATE_LABEL[ticket.state]})
                  </Button>
                ))}
              </Section>
            </Stack.Item>
          )}

          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <InteractionLog interactions={interactions} />
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
