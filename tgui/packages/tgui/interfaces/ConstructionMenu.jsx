import { useMemo, useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Icon, Input, NumberInput, Section, Stack } from '../components';
import { Window } from '../layouts';

const TIME_PER_TICK = 0.1; // BYOND ticks to seconds

const formatTime = (ticks) => {
  if (!ticks) return null;
  const secs = (ticks * TIME_PER_TICK).toFixed(0);
  return `${secs}s`;
};

const RecipeCard = ({ recipe, stackSingular, act }) => {
  const [qty, setQty] = useState(1);
  const maxQty =
    recipe.max_res_amount > 1
      ? Math.min(recipe.max_multiplier, Math.floor(recipe.max_res_amount / recipe.res_amount))
      : 1;

  const outputCount = recipe.res_amount * qty;

  return (
    <Box
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '0.5rem',
        padding: '0.35rem 0.5rem',
        marginBottom: '3px',
        borderRadius: '3px',
        backgroundColor: recipe.can_build
          ? 'rgba(255,255,255,0.04)'
          : 'rgba(0,0,0,0.15)',
        borderLeft: `3px solid ${recipe.can_build ? '#4a8' : '#666'}`,
        opacity: recipe.can_build ? 1 : 0.55,
        transition: 'background-color 0.2s ease',
      }}
    >
      {/* Build icon */}
      <Icon
        name={recipe.on_floor ? 'cube' : 'wrench'}
        style={{
          color: recipe.can_build ? '#8cf' : '#666',
          fontSize: '0.9rem',
          flexShrink: 0,
        }}
      />

      {/* Title + metadata */}
      <Box style={{ flex: 1, minWidth: 0 }}>
        <Box
          style={{
            fontWeight: 'bold',
            fontSize: '0.85rem',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            color: recipe.can_build ? '#fff' : '#888',
          }}
        >
          {recipe.res_amount > 1 ? `${recipe.res_amount}x ` : ''}
          {recipe.title}
        </Box>
        <Box
          style={{
            fontSize: '0.7rem',
            color: 'rgba(255,255,255,0.4)',
            display: 'flex',
            gap: '0.6rem',
            flexWrap: 'wrap',
          }}
        >
          <span style={{ color: '#fc4' }}>
            {recipe.req_amount} {stackSingular}
            {recipe.req_amount !== 1 ? 's' : ''}
            {qty > 1 ? ` × ${qty} = ${recipe.req_amount * qty}` : ''}
          </span>
          {recipe.time ? (
            <span style={{ color: '#8cf' }}>
              <Icon name="clock" style={{ marginRight: '2px' }} />
              {formatTime(recipe.time)}
            </span>
          ) : null}
          {recipe.on_floor ? (
            <span style={{ color: '#f84' }}>
              <Icon name="map-marker" style={{ marginRight: '2px' }} />
              place on floor
            </span>
          ) : null}
        </Box>
      </Box>

      {/* Quantity selector */}
      {maxQty > 1 && recipe.can_build && (
        <Box
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '3px',
            flexShrink: 0,
          }}
        >
          <NumberInput
            value={qty}
            minValue={1}
            maxValue={maxQty}
            step={1}
            onChange={(v) => setQty(v)}
            width="3.5rem"
          />
          <Box
            style={{
              fontSize: '0.65rem',
              color: 'rgba(255,255,255,0.35)',
            }}
          >
            = {outputCount}x
          </Box>
        </Box>
      )}

      {/* Build button */}
      <Button
        icon="hammer"
        disabled={!recipe.can_build}
        color={recipe.can_build ? 'green' : 'transparent'}
        tooltip={
          !recipe.can_build ? `Need ${recipe.req_amount} ${stackSingular}s` : null
        }
        style={{ flexShrink: 0, minWidth: '3.5rem' }}
        onClick={() =>
          act('make', {
            idx: recipe.idx,
            cat_id: recipe.cat_id || '',
            multiplier: qty,
          })
        }
      >
        Build
      </Button>
    </Box>
  );
};

const CategorySection = ({ category, stackSingular, act }) => {
  const [open, setOpen] = useState(true);

  return (
    <Box style={{ marginBottom: '4px' }}>
      <Box
        as="button"
        onClick={() => setOpen(!open)}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '0.4rem',
          width: '100%',
          padding: '0.3rem 0.5rem',
          backgroundColor: category.can_enter
            ? 'rgba(60,100,160,0.3)'
            : 'rgba(60,60,60,0.2)',
          border: `1px solid ${category.can_enter ? 'rgba(100,150,220,0.4)' : 'rgba(100,100,100,0.3)'}`,
          borderRadius: '3px',
          cursor: 'pointer',
          color: category.can_enter ? '#9cf' : '#777',
          fontWeight: 'bold',
          fontSize: '0.8rem',
        }}
      >
        <Icon name={open ? 'chevron-down' : 'chevron-right'} />
        <Box style={{ flex: 1, textAlign: 'left' }}>
          {category.title}
          <Box
            as="span"
            style={{
              fontWeight: 'normal',
              fontSize: '0.7rem',
              color: 'rgba(255,255,255,0.4)',
              marginLeft: '0.5rem',
            }}
          >
            ({category.req_amount} {stackSingular}
            {category.req_amount !== 1 ? 's' : ''} req.)
          </Box>
        </Box>
        <Box
          style={{
            fontSize: '0.65rem',
            color: 'rgba(255,255,255,0.3)',
          }}
        >
          {category.recipes?.length || 0} recipe
          {(category.recipes?.length || 0) !== 1 ? 's' : ''}
        </Box>
      </Box>
      {open && category.can_enter && (
        <Box style={{ paddingLeft: '0.8rem', paddingTop: '3px' }}>
          {(category.recipes || [])
            .filter((r) => r.type === 'recipe')
            .map((r, i) => (
              <RecipeCard
                key={i}
                recipe={r}
                stackSingular={stackSingular}
                act={act}
              />
            ))}
        </Box>
      )}
    </Box>
  );
};

export const ConstructionMenu = () => {
  const { act, data } = useBackend();
  const { name, amount, singular, recipes = [] } = data;
  const [search, setSearch] = useState('');

  const q = search.toLowerCase().trim();

  // Flatten all recipes for search; otherwise use original structure
  const flatRecipes = useMemo(() => {
    const out = [];
    const flatten = (list) => {
      for (const item of list) {
        if (item.type === 'recipe') out.push(item);
        else if (item.type === 'category' && item.recipes)
          flatten(item.recipes);
      }
    };
    flatten(recipes);
    return out;
  }, [recipes]);

  const visibleItems = q
    ? flatRecipes.filter((r) => r.title.toLowerCase().includes(q))
    : recipes;

  const buildableCount = flatRecipes.filter((r) => r.can_build).length;
  const totalCount = flatRecipes.length;

  return (
    <Window
      title={`Construction — ${name}`}
      width={480}
      height={520}
    >
      <style>{`
        @keyframes cm-fadein {
          from { opacity: 0; transform: translateY(-3px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        .cm-list { animation: cm-fadein 0.2s ease-out; }
      `}</style>
      <Window.Content>
        <Stack vertical fill>
          {/* Header */}
          <Stack.Item>
            <Box
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.8rem',
                padding: '0.4rem 0.3rem',
                borderBottom: '1px solid rgba(255,255,255,0.08)',
                marginBottom: '4px',
              }}
            >
              <Icon name="cubes" style={{ color: '#fc4', fontSize: '1.2rem' }} />
              <Box>
                <Box
                  style={{
                    fontWeight: 'bold',
                    fontSize: '1rem',
                    color: '#fc4',
                  }}
                >
                  {amount}× {singular}
                </Box>
                <Box
                  style={{
                    fontSize: '0.7rem',
                    color: 'rgba(255,255,255,0.4)',
                  }}
                >
                  {buildableCount}/{totalCount} recipes available
                </Box>
              </Box>
            </Box>
          </Stack.Item>

          {/* Search */}
          <Stack.Item>
            <Input
              fluid
              placeholder="Search recipes…"
              value={search}
              onInput={(e, v) => setSearch(v)}
            />
          </Stack.Item>

          {/* Recipe list */}
          <Stack.Item grow basis={0} style={{ overflowY: 'auto' }}>
            <Section fitted className="cm-list">
              {q ? (
                // Flat search results
                visibleItems.length === 0 ? (
                  <Box
                    style={{
                      textAlign: 'center',
                      color: 'rgba(255,255,255,0.3)',
                      padding: '2rem',
                      fontStyle: 'italic',
                    }}
                  >
                    No recipes match &ldquo;{search}&rdquo;
                  </Box>
                ) : (
                  visibleItems.map((r, i) => (
                    <RecipeCard
                      key={i}
                      recipe={r}
                      stackSingular={singular}
                      act={act}
                    />
                  ))
                )
              ) : (
                // Structured view
                recipes.map((item, i) => {
                  if (item.type === 'separator')
                    return (
                      <Box
                        key={i}
                        style={{
                          height: '1px',
                          backgroundColor: 'rgba(255,255,255,0.07)',
                          margin: '4px 0',
                        }}
                      />
                    );
                  if (item.type === 'category')
                    return (
                      <CategorySection
                        key={i}
                        category={item}
                        stackSingular={singular}
                        act={act}
                      />
                    );
                  if (item.type === 'recipe')
                    return (
                      <RecipeCard
                        key={i}
                        recipe={item}
                        stackSingular={singular}
                        act={act}
                      />
                    );
                  return null;
                })
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
