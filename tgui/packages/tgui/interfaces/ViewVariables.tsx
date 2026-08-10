import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Divider, Input, Section, Stack } from '../components';
import { Window } from '../layouts';

type DropdownEntry = { separator: true } | { href: string; label: string };

type VVRow = {
  name: string;
  name_ref?: string;
  name_href?: string;
  name_list_length?: number;
  class:
    | 'null'
    | 'text'
    | 'icon'
    | 'file'
    | 'matrix'
    | 'datum'
    | 'list'
    | 'bitfield'
    | 'value';
  value_text?: string;
  value_icon_b64?: string;
  matrix?: [number, number, number, number, number, number];
  value_ref?: string;
  value_href?: string;
  value_type?: string;
  weakref_target_ref?: string;
  weakref_target_href?: string;
  list_length?: number;
  children?: VVRow[];
  edit_href?: string;
  change_href?: string;
  massedit_href?: string;
  remove_href?: string;
};

type Data = {
  ref: string;
  is_list: boolean;
  type: string;
  title: string;
  ref_short: string;
  marked?: boolean;
  tag_index?: number;
  var_edited?: boolean;
  deleted?: boolean;
  header_html?: string;
  sprite_b64?: string;
  dropdown: DropdownEntry[];
  rows: VVRow[];
};

// Replays a byond:// href exactly as if it had been clicked in the old browse() popup —
// see /datum/view_variables_session/ui_act's "click_href" handler.
const useClickHref = () => {
  const { act } = useBackend<Data>();
  return (href: string | undefined) => href && act('click_href', { href });
};

// The old header (vv_get_header() overrides on /atom, /mob, /mob/living) is still raw HTML
// with byond:// hrefs baked in — this intercepts anchor clicks inside it instead of requiring
// every override site to be rewritten to structured data.
const HtmlLinkArea = (props: { readonly html: string }) => {
  const clickHref = useClickHref();
  return (
    <Box
      onClick={(event: React.MouseEvent) => {
        const anchor = (event.target as HTMLElement).closest('a');
        const href = anchor?.getAttribute('href');
        if (href) {
          event.preventDefault();
          clickHref(href);
        }
      }}
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={{ __html: props.html }}
    />
  );
};

const matchesFilter = (row: VVRow, filter: string): boolean => {
  if (!filter) {
    return true;
  }
  const haystack =
    `${row.name} ${row.value_text ?? ''} ${row.value_type ?? ''}`.toLowerCase();
  if (haystack.includes(filter)) {
    return true;
  }
  return !!row.children?.some((child) => matchesFilter(child, filter));
};

const VVRowView = (props: {
  readonly row: VVRow;
  readonly filter: string;
  readonly depth: number;
}) => {
  const { row, filter, depth } = props;
  const clickHref = useClickHref();

  if (!matchesFilter(row, filter)) {
    return null;
  }

  return (
    <Box ml={depth * 1.5}>
      <Stack>
        {!!row.edit_href && (
          <Stack.Item>
            <Button
              content="E"
              tooltip="Edit"
              width="1.5rem"
              onClick={() => clickHref(row.edit_href)}
            />
          </Stack.Item>
        )}
        {!!row.change_href && (
          <Stack.Item>
            <Button
              content="C"
              tooltip="Change"
              width="1.5rem"
              onClick={() => clickHref(row.change_href)}
            />
          </Stack.Item>
        )}
        {!!row.massedit_href && (
          <Stack.Item>
            <Button
              content="M"
              tooltip="Mass modify"
              width="1.5rem"
              onClick={() => clickHref(row.massedit_href)}
            />
          </Stack.Item>
        )}
        {!!row.remove_href && (
          <Stack.Item>
            <Button
              content="-"
              tooltip="Remove"
              width="1.5rem"
              onClick={() => clickHref(row.remove_href)}
            />
          </Stack.Item>
        )}
        <Stack.Item>
          {row.name_href ? (
            <Box as="a" color="label" onClick={() => clickHref(row.name_href)}>
              {row.name}
              {row.name_list_length !== undefined &&
                ` /list (${row.name_list_length})`}
            </Box>
          ) : (
            <Box as="span" color="label">
              {row.name}
            </Box>
          )}
          {' = '}
          {row.class === 'null' && <Box as="span">null</Box>}
          {row.class === 'text' && (
            <Box as="span">&quot;{row.value_text}&quot;</Box>
          )}
          {row.class === 'icon' && (
            <Stack inline verticalAlign="middle">
              <Stack.Item>{row.value_text}</Stack.Item>
              {!!row.value_icon_b64 && (
                <Stack.Item>
                  <img
                    className="icon"
                    src={`data:image/png;base64,${row.value_icon_b64}`}
                  />
                </Stack.Item>
              )}
            </Stack>
          )}
          {row.class === 'file' && (
            <Box as="span">&apos;{row.value_text}&apos;</Box>
          )}
          {row.class === 'matrix' && !!row.matrix && (
            <table className="matrix">
              <tbody>
                <tr>
                  <td>{row.matrix[0]}</td>
                  <td>{row.matrix[1]}</td>
                  <td>0</td>
                </tr>
                <tr>
                  <td>{row.matrix[2]}</td>
                  <td>{row.matrix[3]}</td>
                  <td>0</td>
                </tr>
                <tr>
                  <td>{row.matrix[4]}</td>
                  <td>{row.matrix[5]}</td>
                  <td>1</td>
                </tr>
              </tbody>
            </table>
          )}
          {row.class === 'datum' && (
            <>
              <Box
                as="a"
                color="good"
                onClick={() => clickHref(row.value_href)}
              >
                {row.value_text ? `${row.value_text} ` : ''}
                {row.value_type} {row.value_ref}
              </Box>
              {!!row.weakref_target_ref && (
                <Box
                  as="a"
                  ml={1}
                  color="good"
                  onClick={() => clickHref(row.weakref_target_href)}
                >
                  (Resolve)
                </Box>
              )}
            </>
          )}
          {row.class === 'list' && (
            <Box as="a" color="good" onClick={() => clickHref(row.value_href)}>
              /list ({row.list_length})
            </Box>
          )}
          {row.class === 'bitfield' && <Box as="span">{row.value_text}</Box>}
          {row.class === 'value' && <Box as="span">{row.value_text}</Box>}
        </Stack.Item>
      </Stack>
      {!!row.children && (
        <Box>
          {row.children.map((child, i) => (
            <VVRowView key={i} row={child} filter={filter} depth={depth + 1} />
          ))}
        </Box>
      )}
    </Box>
  );
};

export const ViewVariables = (props) => {
  const { data } = useBackend<Data>();
  const clickHref = useClickHref();
  const [filter, setFilter] = useState('');
  const lowerFilter = filter.toLowerCase();

  const {
    type,
    title,
    ref_short,
    marked,
    tag_index,
    var_edited,
    deleted,
    header_html,
    sprite_b64,
    dropdown = [],
    rows = [],
  } = data;

  return (
    <Window title={title} theme="admin" width={560} height={650}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Section>
              <Stack>
                {!!sprite_b64 && (
                  <Stack.Item>
                    <img
                      className="icon"
                      src={`data:image/png;base64,${sprite_b64}`}
                    />
                  </Stack.Item>
                )}
                <Stack.Item grow>
                  {!!header_html && <HtmlLinkArea html={header_html} />}
                  <Box fontSize="0.85rem" bold>
                    {type}
                  </Box>
                  <Box fontSize="0.85rem" bold>
                    {ref_short}
                  </Box>
                  {!!marked && (
                    <Box color="bad" fontSize="0.85rem" bold>
                      Marked Object
                    </Box>
                  )}
                  {!!tag_index && (
                    <Box color="bad" fontSize="0.85rem" bold>
                      Tagged Datum #{tag_index}
                    </Box>
                  )}
                  {!!var_edited && (
                    <Box color="bad" fontSize="0.85rem" bold>
                      Var Edited
                    </Box>
                  )}
                  {!!deleted && (
                    <Box color="bad" fontSize="0.85rem" bold>
                      Deleted
                    </Box>
                  )}
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Actions">
              <Stack wrap>
                {dropdown.map((entry, i) =>
                  'separator' in entry ? (
                    <Stack.Item key={i} basis="100%">
                      <Divider />
                    </Stack.Item>
                  ) : (
                    <Stack.Item key={i}>
                      <Button onClick={() => clickHref(entry.href)}>
                        {entry.label}
                      </Button>
                    </Stack.Item>
                  ),
                )}
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Input
              fluid
              placeholder="Search..."
              onInput={(_, value) => setFilter(value)}
            />
          </Stack.Item>

          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section fill>
              {rows.map((row, i) => (
                <VVRowView key={i} row={row} filter={lowerFilter} depth={0} />
              ))}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
