--!strict
--[==[
    A hand-built torture fixture for scripts/strip_luau.js.

    Every published module is stripped before it is embedded in the bundle,
    so a stripper bug ships to every user as a silently different library.
    modules/*.luau happen not to contain the shapes below, which is exactly
    why they have to be pinned here: a corpus test can only prove the corpus
    it was given. Each line is a case that has broken, or could break, a
    hand-written Luau lexer.

    Keep this file compiling with `luau-compile --binary`. It is a syntax
    fixture, not a program: `return` at the bottom, never executed.
]==]

-- 1. A `--` that is inside a string is data, not a comment opener.
local plainDouble = "a -- b"
local plainSingle = 'a -- b'
local longZero = [[a -- b]]
local longTwo = [==[
a --[[ not a comment ]] b
]==]

-- 2. ...including inside the text and the expression of an interpolated string.
local interpText = `text -- not a comment`
local interpExpr = `sum = { 1 + 2 } -- still not a comment`
local interpNested = `outer { `inner {1}` } tail`

-- 3. Braces inside an interpolated expression nest. Two separate lexer bugs
--    lived here: a boolean "inside an interpolation?" flag closed the
--    expression at the *first* `}`, and re-entering the walker mid-line made
--    the space after `{` look like indentation, so `{ {1} }` collapsed to
--    `{{1}}` -- which Luau rejects as "double braces are not permitted".
local tableInExpr = `x = { {1, 2} }`
local tableInExpr2 = `y = { ({ ["k"] = "v" }).k }`
local tableInExpr3 = `w = { ({1, 2})[1] }`
local spacedBraces = `z = {  1  }`

-- 4. Escapes that look like they end something.
local escapes = "escaped \" -- and \' still a string"
local bracketInString = "not a long string: [[ nor ]]"
local escapedBraces = `brace as text: \} and \{`
local unicode = `emoji \u{1F600} then {1}`

-- 5. Comment forms, including ones that must be removed entirely.
local afterInline = 1 --[[ inline block ]] + 2
local afterLine = 3 -- trailing line comment
--[=[
	`--` and `[[` and `]]` inside a block comment are prose.
]=]
local afterBlock = 4

-- 6. Line count is load-bearing: the bundle maps runtime errors back to
--    source lines with LineOffsets, so a moved line misreports every error
--    after it. Multi-line strings and multi-line comments must keep theirs.
local multilineString = [[
line one
line two
]]
local multilineTable = {
	-- a comment between entries
	a = 1,
	b = 2,
}

-- 7. A directive is compiler configuration, not prose: it must survive.
--!nolint

-- 8. Nothing after this point.
return {
	plainDouble,
	plainSingle,
	longZero,
	longTwo,
	interpText,
	interpExpr,
	interpNested,
	tableInExpr,
	tableInExpr2,
	tableInExpr3,
	spacedBraces,
	escapes,
	bracketInString,
	escapedBraces,
	unicode,
	afterInline,
	afterLine,
	afterBlock,
	multilineString,
	multilineTable,
}
