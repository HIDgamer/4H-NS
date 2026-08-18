import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Table,
} from '../components';
import { Window } from '../layouts';

type Transaction = {
  date: string;
  time: string;
  target: string;
  purpose: string;
  amount: string;
  terminal: string;
};

type ATMData = {
  machine_id: string;
  locked_down: boolean;
  has_card: boolean;
  card_name: string;
  withdrawal_cooldown: number;
  authenticated: boolean;
  suspended?: boolean;
  owner?: string;
  balance?: number;
  account_number?: number;
  security_level?: number;
  screen?: number;
  transaction_log?: Transaction[];
};

const SCREEN_MAIN = 0;
const SCREEN_SECURITY = 1;
const SCREEN_TRANSFER = 2;
const SCREEN_LOG = 3;

const fmt = (n: number) =>
  '$' + n.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');

export const ATM = () => {
  const { act, data } = useBackend<ATMData>();
  const {
    machine_id,
    locked_down,
    has_card,
    card_name,
    withdrawal_cooldown,
    authenticated,
    suspended,
    owner,
    balance = 0,
    account_number,
    security_level = 0,
    screen = SCREEN_MAIN,
    transaction_log = [],
  } = data;

  return (
    <Window
      title="WY Automatic Teller Machine"
      width={480}
      height={560}
      theme="weyland_yutani"
    >
      <Window.Content>
        <Stack vertical fill>
          {/* Header strip */}
          <Stack.Item>
            <Box
              style={{
                background:
                  'linear-gradient(90deg, #c8980a 0%, #f0c020 50%, #c8980a 100%)',
                padding: '6px 12px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
              }}
            >
              <Box
                style={{
                  fontWeight: 'bold',
                  fontSize: '1rem',
                  color: '#1a1200',
                  letterSpacing: '0.05em',
                }}
              >
                WEYLAND-YUTANI BANKING
              </Box>
              <Box
                style={{
                  fontSize: '0.65rem',
                  color: '#3a2800',
                  opacity: '0.7',
                }}
              >
                {machine_id}
              </Box>
            </Box>
          </Stack.Item>

          {/* Card slot */}
          <Stack.Item>
            <Box
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '6px 10px',
                backgroundColor: 'rgba(255,255,255,0.04)',
                borderBottom: '1px solid rgba(255,255,255,0.08)',
              }}
            >
              <Box
                style={{
                  fontSize: '0.75rem',
                  color: 'rgba(255,255,255,0.45)',
                  minWidth: '3rem',
                }}
              >
                CARD
              </Box>
              <Box
                style={{
                  flex: '1',
                  fontSize: '0.85rem',
                  color: has_card ? '#f0c020' : 'rgba(255,255,255,0.25)',
                }}
              >
                {has_card ? card_name : '— no card inserted —'}
              </Box>
              {has_card && (
                <Button
                  compact
                  icon="eject"
                  color="transparent"
                  onClick={() => act('eject_card')}
                >
                  Eject
                </Button>
              )}
            </Box>
          </Stack.Item>

          {/* Main content */}
          <Stack.Item grow>
            {locked_down ? (
              <NoticeBox mt={2} color="bad" style={{ margin: '12px' }}>
                Terminal locked — maximum PIN attempts exceeded. Please wait.
              </NoticeBox>
            ) : !authenticated ? (
              <LoginScreen />
            ) : suspended ? (
              <NoticeBox mt={2} color="bad" style={{ margin: '12px' }}>
                This account has been suspended and its funds frozen.
              </NoticeBox>
            ) : screen === SCREEN_SECURITY ? (
              <SecurityScreen security_level={security_level} />
            ) : screen === SCREEN_TRANSFER ? (
              <TransferScreen balance={balance} />
            ) : screen === SCREEN_LOG ? (
              <LogScreen logs={transaction_log} />
            ) : (
              <MainScreen
                owner={owner!}
                balance={balance}
                account_number={account_number!}
                withdrawal_cooldown={withdrawal_cooldown}
              />
            )}
          </Stack.Item>

          {/* Footer */}
          <Stack.Item>
            <Box
              style={{
                padding: '4px 10px',
                fontSize: '0.6rem',
                color: 'rgba(255,255,255,0.2)',
                borderTop: '1px solid rgba(255,255,255,0.06)',
              }}
            >
              Weyland-Yutani Corp. All transactions are logged and monitored.
            </Box>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const LoginScreen = () => {
  const { act } = useBackend();
  const [accNum, setAccNum] = useState('');
  const [pin, setPin] = useState('');

  return (
    <Box style={{ padding: '16px' }}>
      <Section title="Account Access">
        <LabeledList>
          <LabeledList.Item label="Account #">
            <Input
              fluid
              placeholder="Account number"
              value={accNum}
              onInput={(_, v) => setAccNum(v)}
            />
          </LabeledList.Item>
          <LabeledList.Item label="PIN">
            <Input
              fluid
              placeholder="PIN"
              value={pin}
              onInput={(_, v) => setPin(v)}
            />
          </LabeledList.Item>
        </LabeledList>
        <Box mt={1}>
          <Button
            fluid
            icon="sign-in-alt"
            color="gold"
            disabled={!accNum && !pin}
            onClick={() => act('attempt_auth', { account_num: accNum, pin })}
          >
            Login
          </Button>
        </Box>
        <Box
          mt={1}
          style={{
            fontSize: '0.7rem',
            color: 'rgba(255,255,255,0.3)',
            textAlign: 'center',
          }}
        >
          Or insert your ID card for automatic login.
        </Box>
      </Section>
    </Box>
  );
};

const MainScreen = ({
  owner,
  balance,
  account_number,
  withdrawal_cooldown,
}: {
  owner: string;
  balance: number;
  account_number: number;
  withdrawal_cooldown: number;
}) => {
  const { act } = useBackend();
  const [amount, setAmount] = useState(0);
  const [withdrawType, setWithdrawType] = useState<'cash' | 'ewallet'>('cash');

  return (
    <Box style={{ padding: '10px' }}>
      {/* Balance display */}
      <Box
        style={{
          textAlign: 'center',
          padding: '16px',
          marginBottom: '10px',
          backgroundColor: 'rgba(240,192,32,0.06)',
          border: '1px solid rgba(240,192,32,0.2)',
          borderRadius: '4px',
        }}
      >
        <Box
          style={{
            fontSize: '0.7rem',
            color: 'rgba(255,255,255,0.4)',
            marginBottom: '4px',
          }}
        >
          Welcome, {owner} — Account #{account_number}
        </Box>
        <Box
          style={{
            fontSize: '2rem',
            fontWeight: 'bold',
            color: '#f0c020',
            letterSpacing: '-0.02em',
          }}
        >
          {fmt(balance)}
        </Box>
        <Box
          style={{
            fontSize: '0.65rem',
            color: 'rgba(255,255,255,0.3)',
            marginTop: '2px',
          }}
        >
          Available balance
        </Box>
      </Box>

      {/* Withdrawal */}
      <Section title="Withdraw">
        <Stack align="center" mb={1}>
          <Stack.Item>
            <Button
              selected={withdrawType === 'cash'}
              icon="money-bill"
              onClick={() => setWithdrawType('cash')}
            >
              Cash
            </Button>
          </Stack.Item>
          <Stack.Item>
            <Button
              selected={withdrawType === 'ewallet'}
              icon="credit-card"
              onClick={() => setWithdrawType('ewallet')}
            >
              Chargecard
            </Button>
          </Stack.Item>
          <Stack.Item grow>
            <NumberInput
              fluid
              value={amount}
              minValue={0}
              maxValue={balance}
              step={100}
              onChange={(v) => setAmount(v)}
            />
          </Stack.Item>
          <Stack.Item>
            <Button
              icon="arrow-down"
              color="green"
              disabled={
                amount <= 0 || amount > balance || withdrawal_cooldown > 0
              }
              tooltip={
                withdrawal_cooldown > 0 ? `Wait ${withdrawal_cooldown}s` : ''
              }
              onClick={() => act('withdraw', { amount, type: withdrawType })}
            >
              Withdraw
            </Button>
          </Stack.Item>
        </Stack>
      </Section>

      {/* Navigation */}
      <Stack mt={1}>
        <Stack.Item grow>
          <Button
            fluid
            icon="exchange-alt"
            onClick={() => act('set_screen', { screen: SCREEN_TRANSFER })}
          >
            Transfer Funds
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            fluid
            icon="list"
            onClick={() => act('set_screen', { screen: SCREEN_LOG })}
          >
            Transactions
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            fluid
            icon="shield-alt"
            onClick={() => act('set_screen', { screen: SCREEN_SECURITY })}
          >
            Security
          </Button>
        </Stack.Item>
      </Stack>
      <Stack mt={1}>
        <Stack.Item grow>
          <Button fluid icon="print" onClick={() => act('print_statement')}>
            Print Statement
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            fluid
            icon="sign-out-alt"
            color="bad"
            onClick={() => act('logout')}
          >
            Logout
          </Button>
        </Stack.Item>
      </Stack>
    </Box>
  );
};

const TransferScreen = ({ balance }: { balance: number }) => {
  const { act } = useBackend();
  const [target, setTarget] = useState('');
  const [amount, setAmount] = useState(0);
  const [purpose, setPurpose] = useState('Funds transfer');

  return (
    <Box style={{ padding: '10px' }}>
      <Section
        title="Transfer Funds"
        buttons={
          <Button
            compact
            icon="arrow-left"
            onClick={() => act('set_screen', { screen: SCREEN_MAIN })}
          >
            Back
          </Button>
        }
      >
        <LabeledList>
          <LabeledList.Item label="Target Account #">
            <Input
              fluid
              placeholder="Account number"
              value={target}
              onInput={(_, v) => setTarget(v)}
            />
          </LabeledList.Item>
          <LabeledList.Item label="Amount">
            <NumberInput
              fluid
              value={amount}
              minValue={0}
              maxValue={balance}
              step={100}
              onChange={(v) => setAmount(v)}
            />
          </LabeledList.Item>
          <LabeledList.Item label="Purpose">
            <Input fluid value={purpose} onInput={(_, v) => setPurpose(v)} />
          </LabeledList.Item>
        </LabeledList>
        <Box mt={1}>
          <Button
            fluid
            icon="paper-plane"
            color="green"
            disabled={!target || amount <= 0 || amount > balance}
            onClick={() =>
              act('transfer', { target_acc: target, amount, purpose })
            }
          >
            Send {amount > 0 ? fmt(amount) : ''}
          </Button>
        </Box>
      </Section>
    </Box>
  );
};

const SecurityScreen = ({ security_level }: { security_level: number }) => {
  const { act } = useBackend();

  const levels = [
    {
      level: 0,
      label: 'Level 0 — Card or account number required',
      desc: 'EFTPOS transactions ask for PIN but do not verify it.',
    },
    {
      level: 1,
      label: 'Level 1 — Account number and PIN required',
      desc: 'Must enter credentials manually for all transactions.',
    },
    {
      level: 2,
      label: 'Level 2 — Card, account number, and PIN required',
      desc: 'Highest security — card physically required.',
    },
  ];

  return (
    <Box style={{ padding: '10px' }}>
      <Section
        title="Account Security"
        buttons={
          <Button
            compact
            icon="arrow-left"
            onClick={() => act('set_screen', { screen: SCREEN_MAIN })}
          >
            Back
          </Button>
        }
      >
        {levels.map((l) => (
          <Box
            key={l.level}
            style={{
              padding: '8px 10px',
              marginBottom: '6px',
              borderRadius: '3px',
              border:
                security_level === l.level
                  ? '1px solid rgba(240,192,32,0.6)'
                  : '1px solid rgba(255,255,255,0.1)',
              backgroundColor:
                security_level === l.level
                  ? 'rgba(240,192,32,0.08)'
                  : 'rgba(255,255,255,0.03)',
              cursor: security_level === l.level ? 'default' : 'pointer',
            }}
            onClick={() =>
              security_level !== l.level &&
              act('change_security', { level: l.level })
            }
          >
            <Box
              style={{
                fontWeight: security_level === l.level ? 'bold' : 'normal',
                color:
                  security_level === l.level
                    ? '#f0c020'
                    : 'rgba(255,255,255,0.7)',
              }}
            >
              {l.label}
            </Box>
            <Box
              style={{
                fontSize: '0.7rem',
                color: 'rgba(255,255,255,0.4)',
                marginTop: '2px',
              }}
            >
              {l.desc}
            </Box>
          </Box>
        ))}
      </Section>
    </Box>
  );
};

const LogScreen = ({ logs }: { logs: Transaction[] }) => {
  const { act } = useBackend();

  return (
    <Box style={{ padding: '10px' }}>
      <Section
        title={`Transactions (${logs.length})`}
        buttons={
          <Stack>
            <Stack.Item>
              <Button compact icon="print" onClick={() => act('print_log')}>
                Print
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                compact
                icon="arrow-left"
                onClick={() => act('set_screen', { screen: SCREEN_MAIN })}
              >
                Back
              </Button>
            </Stack.Item>
          </Stack>
        }
      >
        {logs.length === 0 ? (
          <Box
            style={{
              textAlign: 'center',
              color: 'rgba(255,255,255,0.3)',
              padding: '12px',
            }}
          >
            No transactions recorded.
          </Box>
        ) : (
          <Box style={{ maxHeight: '320px', overflowY: 'auto' }}>
            <Table>
              <Table.Row header>
                <Table.Cell>Date/Time</Table.Cell>
                <Table.Cell>Purpose</Table.Cell>
                <Table.Cell>Target</Table.Cell>
                <Table.Cell style={{ textAlign: 'right' }}>Amount</Table.Cell>
              </Table.Row>
              {[...logs].reverse().map((t, i) => (
                <Table.Row key={i} style={{ fontSize: '0.75rem' }}>
                  <Table.Cell
                    style={{
                      color: 'rgba(255,255,255,0.45)',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {t.date} {t.time}
                  </Table.Cell>
                  <Table.Cell>{t.purpose}</Table.Cell>
                  <Table.Cell style={{ color: 'rgba(255,255,255,0.55)' }}>
                    {t.target}
                  </Table.Cell>
                  <Table.Cell
                    style={{
                      textAlign: 'right',
                      color: String(t.amount).startsWith('(')
                        ? '#ff6060'
                        : '#4cff88',
                      whiteSpace: 'nowrap',
                      fontFamily: 'monospace',
                    }}
                  >
                    {String(t.amount).startsWith('(')
                      ? `-$${String(t.amount).replace(/[()]/g, '')}`
                      : `+$${t.amount}`}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </Box>
        )}
      </Section>
    </Box>
  );
};
