--[[
Design tokens — the numbers behind Astra's type, spacing, icon and surface
rules, in one place so no element invents a scale of its own.

  * type      five sizes (12 / 13 / 14 / 16 / 20) and two weights (400 / 600),
  * lineHeight  the band each size sits in when a row fixes its height,
  * space     the 8pt grid (8 / 12 / 16 / 24) plus a 4px half-step for the
              gap between an icon and its label inside one row,
  * icon      16px inside a nav row or inline with text, 20px standing alone,
  * measure   the prose column cap — roughly 65 characters at body size,
  * hairline  the 1px separator: thickness and resting alpha,
  * row       the standard nav row height.

The rule these tokens exist to serve is the surface rule: a view has one
surface. Sections separate with whitespace or a hairline, never with a nested
box, so an element that carries information owns no card and an element that
carries a control keeps exactly one.
]]

local tokens = {}

--[[
Type scale. Five steps, used as roles rather than as decoration:
  caption   metadata lines and section labels (uppercased)
  label     compact secondary labels
  body      body copy, nav labels, descriptions
  title     card and row titles
  pageTitle the single heading a page opens with
]]
tokens.text = {
    caption = 12,
    label = 13,
    body = 14,
    title = 16,
    pageTitle = 20,
}

--[[
The band a size sits in when its row fixes a height (a TextSize alone leaves
the engine to lay the line out, which is where half-pixel wobble comes from).
]]
tokens.lineHeight = {
    caption = 15,
    label = 16,
    body = 18,
    title = 19,
    pageTitle = 24,
}

--[[
Two weights only. Body copy and labels rest on `regular`, titles and the page
heading on `strong`; nothing in between, so emphasis reads as contrast instead
of as five shades of bold.
]]
tokens.weight = {
    regular = Enum.FontWeight.Regular,
    strong = Enum.FontWeight.SemiBold,
}

--[[
The 8pt grid. `half` (4px) exists for one job only — the gap between an icon
and the label beside it inside a single row — and is not a structural step.
]]
tokens.space = {
    half = 4,
    sm = 8,
    md = 12,
    lg = 16,
    xl = 24,
}

--[[
Icon sizes. `nav` is the sidebar row glyph, `inline` a glyph sitting in a line
of text, `standalone` a glyph that carries a row or a page on its own.
]]
tokens.icon = {
    nav = 16,
    inline = 16,
    standalone = 20,
}

--[[
Prose measure. At body size and the stock family this is about 65 characters —
the point past which a line stops being comfortable to read, so a paragraph
stops widening there even when the window does.
]]
tokens.measure = {
    prose = 468,
}

--[[
The hairline. One pixel, drawn from the theme's stroke colour at
`transparency`, and the only separator a view is allowed to add.
]]
tokens.hairline = {
    thickness = 1,
    transparency = 0.82,
}

-- Standard nav row height (the 36–40px band the rail is tuned around).
tokens.row = {
    height = 36,
}

--[[
Page inset: what an element's `1, -20` width offset means — 10px of page on
each side. Card padding is a separate, larger step (`space.md`); this is the
margin the page itself keeps.
]]
tokens.pageInset = 10

--[[
Alpha ladder for muted copy: one step for a metadata line, one for a label
that is quiet but still legible, and one for a disabled control.
]]
tokens.alpha = {
    meta = 0.55,
    muted = 0.45,
    disabled = 0.65,
}

return tokens
