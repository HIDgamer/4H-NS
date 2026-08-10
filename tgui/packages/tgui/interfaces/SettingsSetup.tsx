import { BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import { Button, LabeledList, Section, Stack } from '../components';
import { Window } from '../layouts';

type Data = {
  hotkeys: BooleanLike;
  tgui_say: BooleanLike;
  tgui_say_light_mode: BooleanLike;
  ui_style: string;
  ui_style_color: string;
  ui_style_alpha: number;
  stylesheet: string;
  hide_statusbar: BooleanLike;
  no_radials_preference: BooleanLike;
  no_radial_labels_preference: BooleanLike;

  show_ooc_flag: BooleanLike;
  ooc_flag: BooleanLike;
  show_view_mc: BooleanLike;
  view_mc: BooleanLike;
  show_publicity: BooleanLike;
  member_public: BooleanLike;
  ghost_ears: BooleanLike;
  ghost_sight: BooleanLike;
  ghost_radio: BooleanLike;
  ghost_spyradio: BooleanLike;
  ghost_hivemind: BooleanLike;
  lang_chat_disabled: BooleanLike;
  langchat_emotes: BooleanLike;

  ambient_occlusion: BooleanLike;
  auto_fit_viewport: BooleanLike;
  adaptive_zoom: number;
  tooltips: BooleanLike;
  tgui_fancy: BooleanLike;
  tgui_lock: BooleanLike;
  hear_admin_sounds: BooleanLike;
  hear_observer_announcements: BooleanLike;
  lobby_music: BooleanLike;
  hear_vox: BooleanLike;
  ghost_vision_pref: string;
  show_metadata: BooleanLike;

  toggle_ignore_self: BooleanLike;
  toggle_help_intent_safety: BooleanLike;
  toggle_middle_mouse_click: BooleanLike;
  toggle_ability_deactivation_off: BooleanLike;
  toggle_directional_attack: BooleanLike;
  toggle_auto_eject_magazine_off: BooleanLike;
  toggle_auto_eject_magazine_to_hand: BooleanLike;
  toggle_eject_magazine_to_hand: BooleanLike;
  toggle_automatic_punctuation: BooleanLike;
  toggle_combat_clickdrag_override: BooleanLike;
  toggle_middle_mouse_swap_hands: BooleanLike;
  toggle_vend_item_to_hand: BooleanLike;
  toggle_ammo_display_type: BooleanLike;

  show_synth_ert: BooleanLike;
  ert_leader: BooleanLike;
  ert_medic: BooleanLike;
  ert_engineer: BooleanLike;
  ert_specialist: BooleanLike;
  ert_smartgunner: BooleanLike;
  ert_synth: BooleanLike;
  ert_misc: BooleanLike;
};

// Fires a named action and shows on/off state — every toggle here maps 1:1 to a named case in
// settings_setup.dm's ui_act(), which resolves it to the right bitfield var + bit internally.
const Toggle = (props: {
  readonly label: string;
  readonly on: boolean;
  readonly action: string;
  readonly onLabel?: string;
  readonly offLabel?: string;
}) => {
  const { act } = useBackend();
  const { label, on, action, onLabel = 'On', offLabel = 'Off' } = props;
  return (
    <LabeledList.Item label={label}>
      <Button color={on ? 'good' : 'bad'} onClick={() => act(action)}>
        {on ? onLabel : offLabel}
      </Button>
    </LabeledList.Item>
  );
};

export const SettingsSetup = () => {
  const { act, data } = useBackend<Data>();

  return (
    <Window
      title="Settings & Special"
      theme="crtlobby"
      width={1000}
      height={750}
    >
      <Window.Content scrollable>
        <Stack>
          <Stack.Item grow basis={0}>
            <Stack vertical>
              <Stack.Item>
                <Section title="Input">
                  <LabeledList>
                    <LabeledList.Item label="Mode">
                      <Button onClick={() => act('hotkeys')}>
                        {data.hotkeys ? 'Hotkeys Mode' : 'Send to Chat'}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Keybinds">
                      <Button onClick={() => act('viewmacros')}>
                        View Keybinds
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Say Input Style">
                      <Button onClick={() => act('inputstyle')}>
                        {data.tgui_say ? 'Modern (default)' : 'Legacy'}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Say Input Color">
                      <Button onClick={() => act('inputcolor')}>
                        {data.tgui_say_light_mode
                          ? 'Lightmode'
                          : 'Darkmode (default)'}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Saved Messages">
                      <Button
                        icon="comment-dots"
                        onClick={() => act('saved_messages')}
                      >
                        Manage Saved Messages
                      </Button>
                    </LabeledList.Item>
                  </LabeledList>
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Section title="UI Customization">
                  <LabeledList>
                    <LabeledList.Item label="Style">
                      <Button onClick={() => act('ui_style')}>
                        {data.ui_style}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Color">
                      <Button onClick={() => act('ui_style_color')}>
                        {data.ui_style_color}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Alpha">
                      <Button onClick={() => act('ui_style_alpha')}>
                        {data.ui_style_alpha}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Stylesheet">
                      <Button onClick={() => act('stylesheet')}>
                        {data.stylesheet}
                      </Button>
                    </LabeledList.Item>
                    <Toggle
                      label="Hide Statusbar"
                      on={!!data.hide_statusbar}
                      action="hide_statusbar"
                      onLabel="TRUE"
                      offLabel="FALSE"
                    />
                    <Toggle
                      label="Prefer Dropdowns Over Radial Menus"
                      on={!!data.no_radials_preference}
                      action="no_radials_preference"
                      onLabel="TRUE"
                      offLabel="FALSE"
                    />
                    {!data.no_radials_preference && (
                      <Toggle
                        label="Hide Radial Menu Labels"
                        on={!!data.no_radial_labels_preference}
                        action="no_radial_labels_preference"
                        onLabel="TRUE"
                        offLabel="FALSE"
                      />
                    )}
                    <LabeledList.Item label="Custom Cursors">
                      <Button onClick={() => act('customcursors')}>
                        Toggle
                      </Button>
                    </LabeledList.Item>
                  </LabeledList>
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Section title="Chat">
                  <LabeledList>
                    {!!data.show_ooc_flag && (
                      <Toggle
                        label="OOC Country Flag"
                        on={!!data.ooc_flag}
                        action="ooc_flag"
                        onLabel="Enabled"
                        offLabel="Disabled"
                      />
                    )}
                    {!!data.show_view_mc && (
                      <Toggle
                        label="View Master Controller Tab"
                        on={!!data.view_mc}
                        action="view_mc"
                        onLabel="TRUE"
                        offLabel="FALSE"
                      />
                    )}
                    {!!data.show_publicity && (
                      <Toggle
                        label="BYOND Membership Publicity"
                        on={!!data.member_public}
                        action="member_public"
                        onLabel="Public"
                        offLabel="Hidden"
                      />
                    )}
                    <Toggle
                      label="Ghost Ears"
                      on={!!data.ghost_ears}
                      action="ghost_ears"
                      onLabel="All Speech"
                      offLabel="Nearest Creatures"
                    />
                    <Toggle
                      label="Ghost Sight"
                      on={!!data.ghost_sight}
                      action="ghost_sight"
                      onLabel="All Emotes"
                      offLabel="Nearest Creatures"
                    />
                    <Toggle
                      label="Ghost Radio"
                      on={!!data.ghost_radio}
                      action="ghost_radio"
                      onLabel="All Chatter"
                      offLabel="Nearest Speakers"
                    />
                    <Toggle
                      label="Ghost Spy Radio"
                      on={!!data.ghost_spyradio}
                      action="ghost_spyradio"
                      onLabel="Hear"
                      offLabel="Silence"
                    />
                    <Toggle
                      label="Ghost Hivemind"
                      on={!!data.ghost_hivemind}
                      action="ghost_hivemind"
                      onLabel="Show"
                      offLabel="Hide"
                    />
                    <Toggle
                      label="Abovehead Chat"
                      on={!data.lang_chat_disabled}
                      action="lang_chat_disabled"
                      onLabel="Show"
                      offLabel="Hide"
                    />
                    <Toggle
                      label="Abovehead Emotes"
                      on={!!data.langchat_emotes}
                      action="langchat_emotes"
                      onLabel="Show"
                      offLabel="Hide"
                    />
                  </LabeledList>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item grow basis={0}>
            <Stack vertical>
              <Stack.Item>
                <Section title="Game">
                  <LabeledList>
                    <Toggle
                      label="Ambient Occlusion"
                      on={!!data.ambient_occlusion}
                      action="ambient_occlusion"
                      onLabel="Enabled"
                      offLabel="Disabled"
                    />
                    <Toggle
                      label="Fit Viewport"
                      on={!!data.auto_fit_viewport}
                      action="auto_fit_viewport"
                      onLabel="Auto"
                      offLabel="Manual"
                    />
                    <Toggle
                      label="Adaptive Zoom"
                      on={!!data.adaptive_zoom}
                      action="adaptive_zoom"
                      onLabel={`${data.adaptive_zoom * 2}x`}
                      offLabel="Disabled"
                    />
                    <Toggle
                      label="Tooltips"
                      on={!!data.tooltips}
                      action="tooltips"
                      onLabel="Enabled"
                      offLabel="Disabled"
                    />
                    <Toggle
                      label="tgui Window Mode"
                      on={!!data.tgui_fancy}
                      action="tgui_fancy"
                      onLabel="Fancy (default)"
                      offLabel="Compatible (slower)"
                    />
                    <Toggle
                      label="tgui Window Placement"
                      on={!!data.tgui_lock}
                      action="tgui_lock"
                      onLabel="Primary monitor"
                      offLabel="Free (default)"
                    />
                    <Toggle
                      label="Play Admin Sounds"
                      on={!!data.hear_admin_sounds}
                      action="hear_admin_sounds"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <Toggle
                      label="Play Announcement Sounds As Ghost"
                      on={!!data.hear_observer_announcements}
                      action="hear_observer_announcements"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <LabeledList.Item label="Meme/Atmospheric Sounds">
                      <Button onClick={() => act('toggle_admin_sound_types')}>
                        Toggle
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Eye Blur Type">
                      <Button onClick={() => act('set_eye_blur_type')}>
                        Set
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Flash Type">
                      <Button onClick={() => act('set_flash_type')}>Set</Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Crit Type">
                      <Button onClick={() => act('set_crit_type')}>Set</Button>
                    </LabeledList.Item>
                    <Toggle
                      label="Play Lobby Music"
                      on={!!data.lobby_music}
                      action="lobby_music"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <Toggle
                      label="Play VOX Announcements"
                      on={!!data.hear_vox}
                      action="hear_vox"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <LabeledList.Item label="Default Ghost Night Vision">
                      <Button onClick={() => act('ghost_vision_pref')}>
                        {data.ghost_vision_pref}
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Random Tip">
                      <Button onClick={() => act('receive_random_tip')}>
                        Read Random Tip of the Round
                      </Button>
                    </LabeledList.Item>
                    {!!data.show_metadata && (
                      <LabeledList.Item label="OOC Notes">
                        <Button onClick={() => act('metadata')}>Edit</Button>
                      </LabeledList.Item>
                    )}
                  </LabeledList>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item grow basis={0}>
            <Stack vertical>
              <Stack.Item>
                <Section title="Gameplay Toggles">
                  <LabeledList>
                    <Toggle
                      label="Being Able to Hurt Yourself"
                      on={!data.toggle_ignore_self}
                      action="toggle_ignore_self"
                    />
                    <Toggle
                      label="Help Intent Safety"
                      on={!!data.toggle_help_intent_safety}
                      action="toggle_help_intent_safety"
                    />
                    <Toggle
                      label="Middle Mouse Ability Activation"
                      on={!!data.toggle_middle_mouse_click}
                      action="toggle_middle_mouse_click"
                    />
                    <Toggle
                      label="Ability Deactivation"
                      on={!data.toggle_ability_deactivation_off}
                      action="toggle_ability_deactivation_off"
                    />
                    <Toggle
                      label="Directional Assist"
                      on={!!data.toggle_directional_attack}
                      action="toggle_directional_attack"
                    />
                    <Toggle
                      label="Magazine Auto-Ejection"
                      on={!data.toggle_auto_eject_magazine_off}
                      action="toggle_auto_eject_magazine_off"
                    />
                    <Toggle
                      label="Magazine Auto-Ejection to Offhand"
                      on={!!data.toggle_auto_eject_magazine_to_hand}
                      action="toggle_auto_eject_magazine_to_hand"
                    />
                    <Toggle
                      label="Magazine Manual Ejection to Offhand"
                      on={!!data.toggle_eject_magazine_to_hand}
                      action="toggle_eject_magazine_to_hand"
                    />
                    <Toggle
                      label="Automatic Punctuation"
                      on={!!data.toggle_automatic_punctuation}
                      action="toggle_automatic_punctuation"
                    />
                    <Toggle
                      label="Combat Click-Drag Override"
                      on={!!data.toggle_combat_clickdrag_override}
                      action="toggle_combat_clickdrag_override"
                    />
                    <Toggle
                      label="Middle-Click Swap Hands"
                      on={!!data.toggle_middle_mouse_swap_hands}
                      action="toggle_middle_mouse_swap_hands"
                    />
                    <Toggle
                      label="Vendors Vending to Hands"
                      on={!!data.toggle_vend_item_to_hand}
                      action="toggle_vend_item_to_hand"
                    />
                    <Toggle
                      label="Semi-Auto Ammo Display Limiter"
                      on={!!data.toggle_ammo_display_type}
                      action="toggle_ammo_display_type"
                    />
                    <LabeledList.Item label="Item Animation Detail">
                      <Button onClick={() => act('switch_item_animations')}>
                        Toggle
                      </Button>
                    </LabeledList.Item>
                    <LabeledList.Item label="Dual Wield Functionality">
                      <Button onClick={() => act('toggle_dualwield')}>
                        Toggle
                      </Button>
                    </LabeledList.Item>
                  </LabeledList>
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Section title="ERT Settings">
                  <LabeledList>
                    <Toggle
                      label="Spawn as Leader"
                      on={!!data.ert_leader}
                      action="ert_leader"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <Toggle
                      label="Spawn as Medic"
                      on={!!data.ert_medic}
                      action="ert_medic"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <Toggle
                      label="Spawn as Engineer"
                      on={!!data.ert_engineer}
                      action="ert_engineer"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <Toggle
                      label="Spawn as Specialist"
                      on={!!data.ert_specialist}
                      action="ert_specialist"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    <Toggle
                      label="Spawn as Smartgunner"
                      on={!!data.ert_smartgunner}
                      action="ert_smartgunner"
                      onLabel="Yes"
                      offLabel="No"
                    />
                    {!!data.show_synth_ert && (
                      <Toggle
                        label="Spawn as Synth"
                        on={!!data.ert_synth}
                        action="ert_synth"
                        onLabel="Yes"
                        offLabel="No"
                      />
                    )}
                    <Toggle
                      label="Spawn as Miscellaneous"
                      on={!!data.ert_misc}
                      action="ert_misc"
                      onLabel="Yes"
                      offLabel="No"
                    />
                  </LabeledList>
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
