import { useBackend } from '../backend';
import { Box, Button, LabeledList, ProgressBar, Section } from '../components';
import { Window } from '../layouts';

type Data = {
  is_elevator: boolean;
  shuttle_state: 'idle' | 'warmup' | 'in_transit' | 'crashed';
  shuttle_status: string;
  shuttle_status_message: string;
  has_docking: boolean;
  docking_status: 'docked' | 'docking' | 'undocking' | 'undocked' | null;
  can_launch: boolean;
  recharging: number;
  recharging_seconds: number;
  recharge_time: number;
  flight_seconds: number;
};

const ENGINE_STATE_LABEL: Record<string, string> = {
  idle: 'Idle',
  warmup: 'Spinning Up',
  in_transit: 'Engaged',
  crashed: 'Crashed',
};

const ENGINE_STATE_COLOR: Record<string, string> = {
  idle: 'label',
  warmup: 'average',
  in_transit: 'good',
  crashed: 'bad',
};

const DOCKING_LABEL: Record<string, string> = {
  docked: 'Docked',
  docking: 'Docking',
  undocking: 'Undocking',
  undocked: 'Undocked',
};

const DOCKING_COLOR: Record<string, string> = {
  docked: 'good',
  docking: 'average',
  undocking: 'average',
  undocked: 'label',
};

export const ShuttleControl = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    is_elevator,
    shuttle_state,
    shuttle_status,
    shuttle_status_message,
    has_docking,
    docking_status,
    can_launch,
    recharging,
    recharging_seconds,
    recharge_time,
    flight_seconds,
  } = data;

  const crashed = shuttle_state === 'crashed';

  return (
    <Window
      title={is_elevator ? 'Elevator Console' : 'Shuttle Control'}
      width={380}
      height={crashed ? 220 : 340}
    >
      <Window.Content>
        <Section title={is_elevator ? 'Elevator Status' : 'Shuttle Status'}>
          <LabeledList>
            <LabeledList.Item label={is_elevator ? 'Elevator' : 'Engine'}>
              <Box color={ENGINE_STATE_COLOR[shuttle_state] ?? 'bad'} bold>
                {ENGINE_STATE_LABEL[shuttle_state] ?? 'Error'}
              </Box>
            </LabeledList.Item>
            {!crashed && (
              <LabeledList.Item label="Location">
                {shuttle_status}
              </LabeledList.Item>
            )}
            {!crashed && !is_elevator && shuttle_status_message && (
              <LabeledList.Item label="Flight Type">
                {shuttle_status_message}
              </LabeledList.Item>
            )}
            {!crashed && has_docking && (
              <LabeledList.Item label="Docking">
                <Box color={DOCKING_COLOR[docking_status ?? ''] ?? 'bad'}>
                  {DOCKING_LABEL[docking_status ?? ''] ?? 'Error'}
                </Box>
              </LabeledList.Item>
            )}
          </LabeledList>
        </Section>

        {!crashed && shuttle_state === 'idle' && recharge_time > 0 && (
          <Section title="Engine Recharge">
            {recharging > 0 ? (
              <>
                <ProgressBar
                  value={recharging}
                  minValue={0}
                  maxValue={recharge_time}
                  color="average"
                />
                <Box mt={1} color="label">
                  Ready in {recharging_seconds}s.
                </Box>
              </>
            ) : (
              <ProgressBar value={1} minValue={0} maxValue={1} color="good">
                Ready
              </ProgressBar>
            )}
          </Section>
        )}

        {!crashed && shuttle_state === 'in_transit' && (
          <Section title="In Flight">
            <Box color="label">
              {flight_seconds > 0
                ? `Flight time remaining: ${flight_seconds}s`
                : 'Underway.'}
            </Box>
          </Section>
        )}

        {!crashed && (
          <Section title={is_elevator ? 'Elevator Control' : 'Shuttle Control'}>
            <Button
              fluid
              icon="arrow-right"
              disabled={!can_launch}
              onClick={() => act('move')}
            >
              {is_elevator ? 'Use Elevator' : 'Launch Shuttle'}
            </Button>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
