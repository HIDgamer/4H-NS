import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Dropdown, Section, Stack, TextArea } from '../components';
import { Window } from '../layouts';

type Slot = {
  channel: string;
  text: string;
};

type Data = {
  slots: Slot[];
  channels: string[];
  max_slots: number;
};

export const SavedMessages = () => {
  const { data } = useBackend<Data>();
  const { slots = [], channels = [] } = data;

  return (
    <Window title="Saved Messages" theme="crtlobby" width={480} height={560}>
      <Window.Content scrollable>
        <Stack vertical>
          <Stack.Item>
            <Box color="label" fontSize="0.85rem">
              Pre-compose up to {data.max_slots} messages and fire any of them
              instantly, whenever you want, without retyping. Bind a key to each
              slot from Settings &amp; Special &gt; View Keybinds (&quot;Send
              Saved Message N&quot;) to fire it without opening this panel.
            </Box>
          </Stack.Item>
          {slots.map((slot, index) => (
            <Stack.Item key={index}>
              <SlotEditor slot={index + 1} data={slot} channels={channels} />
            </Stack.Item>
          ))}
        </Stack>
      </Window.Content>
    </Window>
  );
};

const SlotEditor = (props: {
  readonly slot: number;
  readonly data: Slot;
  readonly channels: string[];
}) => {
  const { act } = useBackend();
  const { slot, data, channels } = props;

  const [channel, setChannel] = useState(data.channel);
  const [text, setText] = useState(data.text);

  const dirty = channel !== data.channel || text !== data.text;

  return (
    <Section
      title={`Slot ${slot}`}
      buttons={
        <>
          <Dropdown
            width="90px"
            options={channels}
            selected={channel}
            onSelected={(value) => setChannel(value)}
          />
          {!!data.text && (
            <Button
              icon="paper-plane"
              tooltip="Send now"
              onClick={() => act('send', { slot })}
            >
              Send
            </Button>
          )}
          {!!data.text && (
            <Button
              icon="trash"
              tooltip="Clear this slot"
              onClick={() => {
                setText('');
                act('clear', { slot });
              }}
            />
          )}
        </>
      }
    >
      <Stack vertical>
        <Stack.Item>
          <TextArea
            height="3rem"
            placeholder="Type a message to save..."
            value={text}
            onChange={(_, value) => setText(value)}
          />
        </Stack.Item>
        {dirty && (
          <Stack.Item>
            <Button
              fluid
              icon="floppy-disk"
              onClick={() => act('save', { slot, channel, text })}
            >
              Save Slot {slot}
            </Button>
          </Stack.Item>
        )}
      </Stack>
    </Section>
  );
};
