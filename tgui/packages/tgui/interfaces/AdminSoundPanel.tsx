import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Divider,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
} from '../components';
import { Window } from '../layouts';

type MobEntry = {
  name: string;
  key: string;
  ref: string;
};

type AdminSoundPanelData = {
  cliented_mobs: MobEntry[];
  last_status?: string;
  last_error?: string;
  resolved_title?: string;
  is_playing: boolean;
};

const AUDIENCE_OPTIONS = [
  'Globally',
  'Marines',
  'Xenos',
  'Ghosts',
  'All In View Range',
  'Single Mob',
];

const SOUND_TYPES = ['Meme', 'Atmospheric'];

export const AdminSoundPanel = () => {
  const { act, data } = useBackend<AdminSoundPanelData>();
  const { cliented_mobs, last_status, last_error, resolved_title, is_playing } =
    data;

  const [sourceMode, setSourceMode] = useState<'web' | 'upload'>('web');
  const [webUrl, setWebUrl] = useState('');
  const [audience, setAudience] = useState('Globally');
  const [selectedMobKey, setSelectedMobKey] = useState('');
  const [soundType, setSoundType] = useState('Meme');
  const [showTitle, setShowTitle] = useState(true);

  const mobOptions = cliented_mobs.map((m) => `${m.name} (${m.key})`);
  const selectedMobLabel = selectedMobKey
    ? cliented_mobs.find((m) => m.key === selectedMobKey)
      ? `${cliented_mobs.find((m) => m.key === selectedMobKey)!.name} (${selectedMobKey})`
      : ''
    : '';

  const handleFetchTitle = () => {
    if (!webUrl.trim()) return;
    act('resolve_url', { url: webUrl.trim() });
  };

  const handlePlay = () => {
    const target_ref =
      audience === 'Single Mob'
        ? cliented_mobs.find((m) => m.key === selectedMobKey)?.ref ?? ''
        : '';
    if (sourceMode === 'web') {
      act('play_web', {
        url: webUrl.trim(),
        audience,
        target_ref,
        sound_type: soundType,
        show_title: showTitle,
      });
    } else {
      act('play_upload', {
        audience,
        target_ref,
        sound_type: soundType,
        show_title: showTitle,
      });
    }
  };

  const handleStop = () => {
    act('stop_all');
  };

  return (
    <Window title="Admin Sound Panel" width={480} height={400} theme="admin">
      <Window.Content scrollable>
        <Stack fill vertical>
          <Stack.Item>
            <Section title="Source">
              <Stack mb={1}>
                <Stack.Item>
                  <Button
                    icon="globe"
                    selected={sourceMode === 'web'}
                    onClick={() => setSourceMode('web')}
                  >
                    Web URL
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="upload"
                    selected={sourceMode === 'upload'}
                    onClick={() => setSourceMode('upload')}
                  >
                    Upload File
                  </Button>
                </Stack.Item>
              </Stack>

              {sourceMode === 'web' ? (
                <Stack align="center">
                  <Stack.Item grow>
                    <Input
                      fluid
                      placeholder="https://… (YouTube, SoundCloud, etc.)"
                      value={webUrl}
                      onInput={(e, value) => setWebUrl(value)}
                      onEnter={() => handleFetchTitle()}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="search"
                      disabled={!webUrl.trim()}
                      onClick={handleFetchTitle}
                      tooltip="Resolve title from URL"
                    >
                      Fetch
                    </Button>
                  </Stack.Item>
                </Stack>
              ) : (
                <Button
                  icon="file-audio"
                  onClick={() => {
                    const target_ref =
                      audience === 'Single Mob'
                        ? cliented_mobs.find((m) => m.key === selectedMobKey)
                            ?.ref ?? ''
                        : '';
                    act('open_file_picker', {
                      audience,
                      target_ref,
                      sound_type: soundType,
                      show_title: showTitle,
                    });
                  }}
                >
                  Choose File…
                </Button>
              )}

              {resolved_title && (
                <Box mt={0.5} color="good" fontSize="0.9em">
                  Title: {resolved_title}
                </Box>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Options">
              <LabeledList>
                <LabeledList.Item label="Audience">
                  <Dropdown
                    selected={audience}
                    options={AUDIENCE_OPTIONS}
                    onSelected={(val) => setAudience(val)}
                    width="14em"
                  />
                </LabeledList.Item>
                {audience === 'Single Mob' && (
                  <LabeledList.Item label="Target">
                    <Dropdown
                      selected={selectedMobLabel || '— select mob —'}
                      options={mobOptions}
                      onSelected={(label) => {
                        const entry = cliented_mobs.find(
                          (m) => `${m.name} (${m.key})` === label,
                        );
                        if (entry) setSelectedMobKey(entry.key);
                      }}
                      width="14em"
                    />
                  </LabeledList.Item>
                )}
                <LabeledList.Item label="Sound Type">
                  <Stack>
                    {SOUND_TYPES.map((type) => (
                      <Stack.Item key={type}>
                        <Button.Checkbox
                          checked={soundType === type}
                          onClick={() => setSoundType(type)}
                        >
                          {type}
                        </Button.Checkbox>
                      </Stack.Item>
                    ))}
                  </Stack>
                </LabeledList.Item>
                <LabeledList.Item label="Announce Title">
                  <Button.Checkbox
                    checked={showTitle}
                    onClick={() => setShowTitle(!showTitle)}
                  >
                    Show title to players
                  </Button.Checkbox>
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Divider />
            <Stack justify="space-between" align="center">
              <Stack.Item>
                <Button.Confirm
                  icon="play"
                  color="good"
                  disabled={sourceMode === 'web' && !webUrl.trim()}
                  confirmContent={`Play to ${audience}?`}
                  onClick={handlePlay}
                >
                  Play Sound
                </Button.Confirm>
                <Button ml={1} icon="stop" color="bad" onClick={handleStop}>
                  Stop All
                </Button>
              </Stack.Item>
              {is_playing && (
                <Stack.Item color="good" fontSize="0.85em">
                  Now playing: {resolved_title || 'Admin sound'}
                </Stack.Item>
              )}
            </Stack>

            {last_error && (
              <NoticeBox mt={1} color="bad">
                {last_error}
              </NoticeBox>
            )}
            {last_status && !last_error && (
              <Box mt={1} color="label" fontSize="0.85em">
                {last_status}
              </Box>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
