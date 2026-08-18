import { useState } from 'react';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  ColorBox,
  DmIcon,
  Modal,
  Stack,
  Tooltip,
} from 'tgui/components';
import { Window } from 'tgui/layouts';

type PickerData = {
  icon: string;
  body_types: { name: string; icon: string }[];
  skin_colors: { name: string; icon: string; color: string }[];

  body_type: string;
  skin_color: string;
  gender: string;
};

export const BodyPicker = () => {
  const { act, data } = useBackend<PickerData>();

  const { icon, gender, body_type, skin_color, body_types } = data;

  const [picker, setPicker] = useState<'type' | undefined>();

  const unselectedBodyType = body_types.filter(
    (val) => val.icon !== body_type,
  )[0];

  return (
    <Window width={390} height={180} theme={'crtblue'}>
      <Window.Content className="BodyPicker">
        {picker && (
          <Modal m={1}>
            <TypePicker picker={setPicker} />
          </Modal>
        )}
        <Stack>
          <Stack.Item>
            <Stack vertical>
              <Stack.Item>
                <DmIcon
                  icon={icon}
                  icon_state={`${skin_color}_torso_${body_type}_${gender}`}
                  width={'128px'}
                  mt={-5}
                />
              </Stack.Item>
              <Stack width="100%" fill mt={-4} justify="space-around">
                <Stack.Item>
                  <Button width={'4em'} height={'4em'}>
                    <Tooltip
                      content={'Change Body Type'}
                      position="bottom-start"
                    >
                      <Box
                        position="relative"
                        onClick={() => setPicker('type')}
                      >
                        <DmIcon
                          position="relative"
                          icon={icon}
                          icon_state={`${skin_color}_torso_${unselectedBodyType.icon}_${gender}`}
                          width={'80px'}
                          right={'22px'}
                          bottom={'18px'}
                        />
                      </Box>
                    </Tooltip>
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button width={'4em'} height={'4em'}>
                    <Tooltip content={'Toggle Gender'} position="bottom-start">
                      <Box position="relative" onClick={() => act('gender')}>
                        <DmIcon
                          position="relative"
                          icon={icon}
                          icon_state={`${skin_color}_torso_${body_type}_${gender === 'male' ? 'female' : 'male'}`}
                          width={'80px'}
                          right={'22px'}
                          bottom={'18px'}
                        />
                      </Box>
                    </Tooltip>
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <ColorOptions />
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const TypePicker = (props: { readonly picker: (_) => void }) => {
  const { data, act } = useBackend<PickerData>();

  const { picker } = props;

  const { body_type, body_types, skin_color, gender, icon } = data;

  return (
    <Stack>
      {body_types.map((type) => (
        <Stack.Item key={type.name}>
          <Tooltip content={type.name}>
            <Box
              onClick={() => {
                picker(undefined);
                act('type', { name: type.name });
              }}
              position="relative"
              className={`typePicker ${body_type === type.icon ? 'active' : ''}`}
            >
              <DmIcon
                icon={icon}
                icon_state={`${skin_color}_torso_${type.icon}_${gender}`}
                width={'80px'}
              />
            </Box>
          </Tooltip>
        </Stack.Item>
      ))}
    </Stack>
  );
};

const ColorOptions = () => {
  const { data, act } = useBackend<PickerData>();

  const { skin_color, skin_colors } = data;

  return (
    <Stack wrap={'wrap'} width={'250px'}>
      {skin_colors.map((color) => (
        <Stack.Item key={color.name} className="colorPickerContainer">
          <ColorBox
            color={color.color}
            p={3.5}
            mt={0.5}
            onClick={() => act('color', { name: color.name })}
            className={`colorPicker ${skin_color === color.icon ? 'active' : ''}`}
          />
        </Stack.Item>
      ))}
    </Stack>
  );
};
