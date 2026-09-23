local coreState = require(script.Parent.Parent.core.state)
local logger = require(script.Parent.log)

local locale = {}

export type LocaleToken = { [any]: string }
export type Translator = (source: string, localeId: string) -> string?
export type TranslationTables = { [string]: { [string]: string } }

locale.strings = {} :: TranslationTables
locale.current = "en"
locale.translator = nil :: Translator?

local tokenKey = {}

local function languagePrefix(id: string): string
    return string.match(id, "^(%a+)") or id
end

function locale.t(value: unknown): unknown
    if type(value) ~= "string" or value == "" then
        return value
    end
    return { [tokenKey] = value }
end

function locale.isToken(candidate: unknown): boolean
    return type(candidate) == "table" and type((candidate :: { [any]: unknown })[tokenKey]) == "string"
end

function locale.sourceOf(token: LocaleToken): string
    return token[tokenKey]
end

function locale.resolve(text: unknown): any
    if type(text) ~= "string" then
        return text
    end

    if locale.translator then
        local ok, translated = pcall(locale.translator, text, locale.current)
        if ok and type(translated) == "string" and translated ~= "" then
            return translated
        end
    end

    local exactTable = locale.strings[locale.current]
    if exactTable and exactTable[text] then
        return exactTable[text]
    end

    local prefixTable = locale.strings[languagePrefix(locale.current)]
    if prefixTable and prefixTable[text] then
        return prefixTable[text]
    end

    return text
end

function locale.register(tables: TranslationTables?)
    if type(tables) ~= "table" then
        return
    end
    for id, entryTable in tables do
        if type(id) == "string" and type(entryTable) == "table" then
            id = string.lower(id)
            local target = locale.strings[id]
            if not target then
                target = {}
                locale.strings[id] = target
            end
            for sourceKey, sourceText in entryTable do
                if type(sourceKey) == "string" and type(sourceText) == "string" then
                    target[sourceKey] = sourceText
                else
                    logger.warn(`Astra: skipping a '{id}' translation, entries must be string to string.`)
                end
            end
        end
    end
end

function locale.setActive(requestedLocale: string?): string
    locale.current = if type(requestedLocale) == "string" and requestedLocale ~= "" then string.lower(requestedLocale) else "en"
    return locale.current
end

function locale.detect(): string
    local id = coreState.localizationService.RobloxLocaleId
    if type(id) == "string" and id ~= "" then
        return string.lower(id)
    end
    return "en"
end

return locale
