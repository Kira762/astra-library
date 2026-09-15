local state = Astra.Core.state
local player = state.localPlayer
player.UserId = 42
player.AccountAge = 10
local now = os.time()
local created = os.time({ year = 2020, month = 2, day = 29, hour = 12 })
DateTime = { fromIsoDate = function(value)
    assert(value == "2020-02-29T12:00:00Z", "Parse the API's timestamp, not AccountAge")
    return { UnixTimestamp = created }
end }
local requests = 0
request = function(options)
    if options.Url == "https://users.roblox.com/v1/users/42" then
        requests += 1
        return { StatusCode = 200, Body = '{"created":"2020-02-29T12:00:00Z"}' }
    end
    return { StatusCode = 503, Body = "" }
end
local window = Astra:CreateWindow({ name = "Account created test" })
TestPump(0.6)
EnableProfileCard(window) -- profile card is lazy until the user enables it
assert(window.profileJoinDateValue.Text == "29 Feb 2020", "Show the exact UTC creation date")
assert(window.profileAccountAgeValue.Text:match("years ago$"), "Show elapsed years")
assert(requests == 1, "Request once, not every refresh")
for _, case in {
    { 8 * 3600, "8 hours ago" },
    { 3600, "1 hour ago" },
    { 8 * 86400, "8 days ago" },
    { 86400, "1 day ago" },
    { 3 * 2629800, "3 months ago" },
    { 2629800, "1 month ago" },
    { 31557600, "1 year ago" },
    { 30, "Less than an hour ago" },
} do
    window.profileAccountCreatedAt = now - case[1]
    window:SetProfile({})
    assert(window.profileAccountAgeValue.Text == case[2], window.profileAccountAgeValue.Text)
end
assert(requests == 1, "Repeated updates must not spam Roblox")

-- A failed API must not present a date calculated from rounded days as exact.
player.UserId = 43
window:SetProfile({})
TestPump(0.1)
assert(window.profileJoinDateValue.Text == "—", "Failed lookup has no exact date")
assert(window.profileAccountAgeValue.Text == "~ 10 days ago", "AccountAge fallback is approximate")
player.AccountAge = 0
window:SetProfile({})
assert(window.profileAccountAgeValue.Text == "Less than a day ago", "No invented hour precision")
state.localPlayer = nil
window:SetProfile({})
assert(window.profileJoinDateValue.Text == "—" and window.profileAccountAgeValue.Text == "—", "Missing player clears dates")
state.localPlayer = player
print("PROFILE CREATED: date, elapsed units, cached requests and fallbacks passed")
