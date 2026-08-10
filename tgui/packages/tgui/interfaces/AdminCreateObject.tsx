import { playClickBlip } from 'common/audio';
import { BooleanLike } from 'common/react';
import { useState } from 'react';

import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  NumberInput,
  Section,
  Stack,
} from '../components';
import { VirtualList } from '../components/VirtualList';
import { Window } from '../layouts';

const DIRECTIONS = [
  { value: 1, label: 'North' },
  { value: 2, label: 'South' },
  { value: 4, label: 'East' },
  { value: 8, label: 'West' },
];

const WHERE_OPTIONS = ['On Floor', 'In Marked Object'];

const MAX_TYPES = 5;

type Data = {
  types: string[];
  categories: string[];
  ui_effects_enabled: BooleanLike;
};

export const AdminCreateObject = () => {
  const { act, data } = useBackend<Data>();
  const { types, categories, ui_effects_enabled = true } = data;

  const [filter, setFilter] = useState('');
  const [category, setCategory] = useState('/obj');
  const [selected, setSelected] = useState<string[]>([]);
  const [offsetX, setOffsetX] = useState(0);
  const [offsetY, setOffsetY] = useState(0);
  const [offsetZ, setOffsetZ] = useState(0);
  const [offsetMode, setOffsetMode] = useState<'relative' | 'absolute'>(
    'relative',
  );
  const [count, setCount] = useState(1);
  const [direction, setDirection] = useState(2);
  const [customName, setCustomName] = useState('');
  const [where, setWhere] = useState('On Floor');

  const lowerFilter = filter.toLowerCase();
  const filtered = types.filter(
    (t) =>
      (category === '/obj' || t.startsWith(category)) &&
      (!lowerFilter || t.toLowerCase().includes(lowerFilter)),
  );

  const dirLabel =
    DIRECTIONS.find((d) => d.value === direction)?.label ?? 'South';

  const toggleSelected = (type: string) => {
    setSelected((prev) => {
      if (prev.includes(type)) {
        return prev.filter((t) => t !== type);
      }
      if (prev.length >= MAX_TYPES) {
        return prev;
      }
      return [...prev, type];
    });
    if (ui_effects_enabled) {
      playClickBlip();
    }
  };

  const handleSpawn = () => {
    if (!selected.length) return;
    act('spawn', {
      types: selected,
      offset_x: offsetX,
      offset_y: offsetY,
      offset_z: offsetZ,
      offset_type: offsetMode,
      count,
      dir: direction,
      name: customName || null,
      where: where === 'On Floor' ? 'onfloor' : 'inmarked',
    });
    if (ui_effects_enabled) {
      new Audio(resolveAsset('admin_spawn_confirm.ogg')).play().catch(() => {});
    }
  };

  return (
    <Window title="Create Object" width={560} height={640} theme="admin">
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section title="Object Type (up to 5)">
              <Stack mb={1}>
                <Stack.Item grow>
                  <Input
                    fluid
                    autoFocus
                    placeholder="Search object types…"
                    value={filter}
                    onInput={(e, value) => setFilter(value)}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Dropdown
                    selected={category}
                    options={categories}
                    onSelected={(val) => setCategory(val)}
                    width="14em"
                  />
                </Stack.Item>
              </Stack>
              <Box
                style={{
                  height: '260px',
                  border: '1px solid var(--admin-primary-border)',
                  overflowY: 'auto',
                  fontFamily: 'monospace',
                  fontSize: '0.85em',
                }}
              >
                <VirtualList>
                  {filtered.map((type) => (
                    <Box
                      key={type}
                      p={0.5}
                      style={{
                        cursor: 'pointer',
                        background: selected.includes(type)
                          ? 'var(--admin-primary-soft)'
                          : 'transparent',
                        borderLeft: selected.includes(type)
                          ? '2px solid var(--admin-primary)'
                          : '2px solid transparent',
                      }}
                      onClick={() => toggleSelected(type)}
                    >
                      {selected.includes(type) ? '✓ ' : ''}
                      {type}
                    </Box>
                  ))}
                </VirtualList>
              </Box>
              {!!selected.length && (
                <Box mt={0.5} color="label" fontSize="0.85em">
                  Selected ({selected.length}/{MAX_TYPES}):{' '}
                  {selected.join(', ')}
                </Box>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Spawn Options">
              <LabeledList>
                <LabeledList.Item label="Offset">
                  <Stack align="center">
                    <Stack.Item>
                      <NumberInput
                        value={offsetX}
                        minValue={-255}
                        maxValue={255}
                        step={1}
                        width="4em"
                        onChange={(val) => setOffsetX(val)}
                        unit="X"
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={offsetY}
                        minValue={-255}
                        maxValue={255}
                        step={1}
                        width="4em"
                        onChange={(val) => setOffsetY(val)}
                        unit="Y"
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <NumberInput
                        value={offsetZ}
                        minValue={-255}
                        maxValue={255}
                        step={1}
                        width="4em"
                        onChange={(val) => setOffsetZ(val)}
                        unit="Z"
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        checked={offsetMode === 'absolute'}
                        onClick={() =>
                          setOffsetMode(
                            offsetMode === 'absolute' ? 'relative' : 'absolute',
                          )
                        }
                      >
                        Absolute
                      </Button.Checkbox>
                    </Stack.Item>
                  </Stack>
                </LabeledList.Item>
                <LabeledList.Item label="Count (each)">
                  <NumberInput
                    value={count}
                    minValue={1}
                    maxValue={100}
                    step={1}
                    width="4em"
                    onChange={(val) => setCount(val)}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Direction">
                  <Dropdown
                    selected={dirLabel}
                    options={DIRECTIONS.map((d) => d.label)}
                    onSelected={(label) => {
                      const dir = DIRECTIONS.find((d) => d.label === label);
                      if (dir) setDirection(dir.value);
                    }}
                    width="8em"
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Custom Name">
                  <Input
                    fluid
                    placeholder="(optional)"
                    value={customName}
                    onInput={(e, value) => setCustomName(value)}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Place">
                  <Dropdown
                    selected={where}
                    options={WHERE_OPTIONS}
                    onSelected={(val) => setWhere(val)}
                    width="12em"
                  />
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Stack justify="flex-end">
              <Stack.Item>
                <Button.Confirm
                  icon="plus-circle"
                  color="good"
                  disabled={!selected.length}
                  onClick={handleSpawn}
                  tooltip={
                    !selected.length
                      ? 'Select at least one object type'
                      : undefined
                  }
                >
                  Spawn
                </Button.Confirm>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
