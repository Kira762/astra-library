local services = require(script.Parent.Parent.utilities.services)
local constants = require(script.Parent.Parent.utilities.constants)
local log = require(script.Parent.Parent.utilities.log)
local fileSystemManager = require(script.Parent.Parent.utilities.filesystemManager)
local assetResolver = require(script.Parent.Parent.utilities.assetResolver)
local fontManager = require(script.Parent.Parent.utilities.fontManager)
local tokens = require(script.Parent.Parent.utilities.tokens)

type FileSystemManager = fileSystemManager.FileSystemManager
type AssetResolver = assetResolver.AssetResolver
type FontManager = fontManager.FontManager

export type VariablesState = {
	secureMode: boolean,
	coreGui: CoreGui,
	workspace: Workspace,
	runService: RunService,
	userInputService: UserInputService,
	guiService: GuiService,
	localPlayer: Player?,
	tweenService: TweenService,
	httpService: HttpService,
	textService: TextService,
	replicatedStorage: ReplicatedStorage,
	localizationService: LocalizationService,
	guiContainer: Instance,

	fallbackFont: Font,
	fileSystemManager: FileSystemManager,
	assetResolver: AssetResolver,
	fontManager: FontManager,
	setFallbackFont: (font: Enum.Font | Font) -> (),
	fontChoice: string,
	brandFont: (weight: Enum.FontWeight?) -> Font,
	setFontChoice: (choice: string) -> (),
	brandFontPair: () -> (Font, Font),
}

local state = {} :: VariablesState

state.secureMode = (function()
	if typeof(getgenv) ~= "function" then
		return false
	end
	local ok, result = pcall(function()
		return getgenv().ASTRA_SECURE
	end)
	return ok and result == true
end)()

state.coreGui = services.getService("CoreGui") :: CoreGui
state.workspace = services.getService("Workspace") :: Workspace
state.runService = services.getService("RunService") :: RunService
state.userInputService = services.getService("UserInputService") :: UserInputService
state.guiService = services.getService("GuiService") :: GuiService
state.localPlayer = (services.getService("Players") :: Players).LocalPlayer
state.tweenService = services.getService("TweenService") :: TweenService
state.httpService = services.getService("HttpService") :: HttpService
state.textService = services.getService("TextService") :: TextService
state.replicatedStorage = services.getService("ReplicatedStorage") :: ReplicatedStorage
state.localizationService = services.getService("LocalizationService") :: LocalizationService

state.guiContainer = (function(): Instance
	if state.runService:IsStudio() then
		local player = state.localPlayer
		if player then
			return player.PlayerGui
		end
		return state.coreGui
	end
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end
	return state.coreGui
end)()

log.setSecureModeSource(function()
	return state.secureMode
end)

state.fallbackFont = Font.fromEnum(Enum.Font.BuilderSans)

--[[
Live font selection behind the Font/TitleFont theme keys: "default"
(stock fallback family) or "brand" (constants.brandFontName). Library-wide
like the motion profile, since theme resolution reads it on every resolve.
]]
state.fontChoice = constants.defaultFontChoice

state.fileSystemManager = fileSystemManager.new()
state.assetResolver =
	assetResolver.new(true, assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl) :: AssetResolver
state.fontManager = fontManager.new(
	state.fileSystemManager:getAssetsFolder("fonts"),
	false,
	true,
	assetResolver.Enum.AssetDownloadUrl.RoProxyDownloadUrl,
	{
		saveToDisk = true,
		skipCache = false,
		fallbackFont = state.fallbackFont,
	}
) :: FontManager

function state.setFallbackFont(font: Enum.Font | Font)
	if typeof(font) == "EnumItem" then
		font = Font.fromEnum(font)
	end
	if typeof(font) == "Font" then
		state.fallbackFont = font
		state.fontManager.defaultOptions.fallbackFont = font
	end
end

--[[
The two weights the interface uses, and the only two: body copy and labels
rest on `regular`, titles and the page heading on `strong`. Both are read
from the design tokens so a weight can never be introduced element by
element (see utilities/tokens.luau).
]]
local regularWeight = tokens.weight.regular
local strongWeight = tokens.weight.strong

--[[
The neutral UI face behind the `brand` selection (Settings → Appearance →
Font). Resolved through the stock font catalogue by family name and cached
per weight: a host that never selects it never pays for it, and where the
catalogue cannot answer the library keeps the stock fallback family instead
of rendering nothing.
]]
local brandFaces = {}
local function brandFace(weight: Enum.FontWeight?): Font
	local key = tostring(weight)
	local cached = brandFaces[key]
	if cached then
		return cached
	end
	local resolved
	local ok, font = pcall(function()
		return Font.fromName(constants.brandFontName, weight)
	end)
	if ok and typeof(font) == "Font" then
		resolved = font
	else
		resolved = Font.new(state.fallbackFont.Family, weight)
	end
	brandFaces[key] = resolved
	return resolved
end

function state.brandFont(weight: Enum.FontWeight?): Font
	if state.secureMode or state.fontChoice ~= "brand" then
		return Font.new(state.fallbackFont.Family, weight)
	end
	return brandFace(weight)
end

function state.setFontChoice(choice: string)
	state.fontChoice = if choice == "brand" then "brand" else "default"
end

--[[
The pair the theme keys and the runtime font switch apply: body weight
first, title weight second. Both selections are neutral UI faces — the
stock family, or the catalogue family named in constants — so the pair
differs only by its letterforms, never by its weight scale.
]]
function state.brandFontPair(): (Font, Font)
	if state.fontChoice == "brand" then
		local bodyFont = brandFace(regularWeight)
		local titleFont = brandFace(strongWeight)
		if bodyFont and titleFont then
			return bodyFont, titleFont
		end
	end
	local family = state.fallbackFont.Family
	return Font.new(family, regularWeight), Font.new(family, strongWeight)
end

return state
