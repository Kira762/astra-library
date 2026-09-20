# GitHub `push` event -> Discord webhook payload.
#
#   input   the event payload GitHub hands the workflow ($GITHUB_EVENT_PATH)
#   output  one JSON object, ready to POST to a Discord webhook URL
#   env     DISCORD_EMBED_COLOR  decimal accent colour, default 2829617
#
# Run it on its own with:
#   jq -f .github/scripts/discord-embed.jq event.json
#
# The embed it builds:
#
#   author       repository avatar + owner/repo, linked to the repository
#   title        "Pushed 3 commits to main" / "Created branch x" / "Published
#                tag v1" / "Deleted branch x", linked to the compare view
#   description  the commit log - one line per commit, newest last, capped
#   fields       Branch | Commit | Files, inline, one row of three
#   footer       "Pushed by <login>" beside the commit timestamp
#   color        $color - a neutral bar. Discord's dark-theme embed background
#                is #2B2D31 (2829617), so the default accent disappears into
#                the message instead of drawing a green stripe across the
#                channel. Light theme is #F2F3F5 (15922165); set
#                DISCORD_EMBED_COLOR to that if the channel runs light.
#
# Two rules this file holds to:
#
#  1. Nothing from Git reaches Discord unencoded. Commit messages, author
#     names and refs are jq strings, so the encoder escapes the quotes,
#     backslashes and newlines a hand-built payload would trip over.
#  2. Every Discord limit is enforced here, not hoped for. One oversized field
#     turns the whole request into a 400 and the channel hears nothing:
#     title 256, description 4096, field value 1024, footer 2048, author 256.

# --- helpers -----------------------------------------------------------------

# Any value -> one display line. Tabs and wrapped message bodies collapse to a
# single space so the log stays one line per commit.
def one_line($fallback):
  ((. // $fallback) | tostring)
  | gsub("\r"; "")
  | split("\n")[0]
  | gsub("[[:space:]]+"; " ")
  | if length == 0 then $fallback else . end;

# Shorten to $limit characters, marking the cut and never ending on a space
# right before the ellipsis.
def clamp($limit):
  (tostring) as $text
  | if ($text | length) <= $limit then
      $text
    elif $limit <= 1 then
      $text[0:$limit]
    else
      ($text[0:($limit - 1)] | rtrimstr(" ")) + "…"
    end;

# Looks like a commit SHA? The all-zero placeholder GitHub sends for "this ref
# did not exist yet" / "this ref is gone now" is not one.
def is_sha:
  (tostring) as $text
  | ($text | length) >= 7
    and ($text | test("^[0-9a-fA-F]+$"))
    and ($text | test("^0+$") | not);

def short_sha: (tostring) | if length > 7 then .[0:7] else . end;

# Text safe to put inside a Markdown link label: `[` and `]` would close the
# label early, `\` would escape whatever follows.
def link_label: (tostring) | gsub("[\\[\\]\\\\]"; "");

def link($text; $url): "[" + ($text | link_label) + "](" + $url + ")";

# The commit log, kept inside $limit. Commits that do not fit are counted, not
# silently dropped, and the count points at the compare link in the title.
def commit_log($limit; $subject_limit; $repo_url):
  if length == 0 then
    ""
  else
    (map(
       . as $commit
       | (((($commit.id // "") | tostring))) as $id
       | "- [`"
       + ($id | short_sha)
       + "`]("
       + ((($commit.url // "") | tostring)
          | if length > 0 then . elif ($id | length) > 0 then ($repo_url + "/commit/" + $id) else $repo_url end)
       + ") "
       + (((.message // "") | one_line("(no commit message)")) | clamp($subject_limit))
       + " — "
       + (((.author.name // .committer.name // "") | tostring) | one_line("unknown author") | clamp(80))
     )) as $lines
    | (reduce range(0; ($lines | length)) as $i (
        {kept: [], used: 0, dropped: 0};
        if .dropped > 0 then
          .
        else
          ($lines[$i]) as $line
          | (if (.kept | length) > 0 then 1 else 0 end) as $separator
          | if (.used + $separator + ($line | length)) <= $limit then
              .kept += [$line] | .used += ($separator + ($line | length))
            else
              .dropped = (($lines | length) - $i)
            end
        end
      ))
    | (.kept
       + (if .dropped > 0 then
            ["*… and " + (.dropped | tostring) + " more commit(s) — open the compare link above.*"]
          else
            []
          end))
    | join("\n")
    | clamp($limit)
  end;

# --- the event ---------------------------------------------------------------

. as $event
| ($event.repository // {}) as $repo
| (($repo.owner // $repo.organization // {}) | .avatar_url // null) as $repo_icon
| ($event.sender // {}) as $sender
| ($event.pusher // {}) as $pusher

# Repository identity.
| (($repo.html_url // ("https://github.com/" + (($repo.full_name // "") | tostring)))
   | tostring | rtrimstr("/")) as $repo_url
| (($repo.full_name // $repo.name // "Repository") | tostring) as $repo_name

# Who pushed. `sender` is the account GitHub attributes the push to; `pusher`
# is the fallback shape older payloads use.
| (($sender.login // $pusher.name // "unknown") | tostring | one_line("unknown")) as $actor_login
| (($sender.html_url // ("https://github.com/" + $actor_login)) | tostring) as $actor_url

# Ref: branch or tag, without the refs/ prefix.
| (($event.ref // "") | tostring) as $raw_ref
| (if ($raw_ref | startswith("refs/tags/")) then
     {kind: "tag", name: ($raw_ref | sub("^refs/tags/"; ""))}
   elif ($raw_ref | startswith("refs/heads/")) then
     {kind: "branch", name: ($raw_ref | sub("^refs/heads/"; ""))}
   else
     {kind: "branch", name: $raw_ref}
   end) as $ref
| ((if ($ref.name | length) > 0 then $ref.name else "unknown-ref" end) | one_line("unknown-ref")) as $ref_name
| (($repo_url + "/tree/" + $ref_name)) as $ref_url

# Commits arrive oldest first, so the head commit is the last one.
| ($event.commits // []) as $commits
| ($commits | length) as $count
| (($event.head_commit // (if $count > 0 then $commits[-1] else null end)) // {}) as $head
| ((($head.id // "") | tostring)) as $head_id
| (if ($head_id | is_sha) then
     $head_id
   elif (($event.after // "") | tostring | is_sha) then
     ($event.after | tostring)
   else
     ""
   end) as $sha
| ((if ($sha | length) > 0 then ($repo_url + "/commit/" + $sha) else $repo_url end)) as $commit_url

# Compare link: GitHub ships one on the event; rebuild it when it is missing.
| (if (($event.compare // "") | tostring | length > 0) then
     ($event.compare | tostring)
   elif (($event.before // "") | tostring | is_sha) and ($sha | is_sha) then
     ($repo_url + "/compare/" + (($event.before | tostring)[0:7]) + "..." + ($sha[0:7]))
   else
     $commit_url
   end) as $target_url

# File churn, from the per-commit file lists. Unique paths, so a file touched
# by three commits counts once; a path both added and removed in one push
# (renamed, or added then reverted) counts as neither.
| ([$commits[] | ((.added // [])[])] | unique) as $added
| ([$commits[] | ((.removed // [])[])] | unique) as $removed
| ([$commits[] | ((.modified // [])[])] | unique) as $modified
| (($added + $removed + $modified) | unique) as $files
| (($added - $removed) | length) as $created_files
| (($removed - $added) | length) as $deleted_files
| ((if ($files | length) > 0 then
     (($files | length) | tostring)
     + (if ($files | length) == 1 then " file" else " files" end)
     + " · "
     + ($created_files | tostring)
     + " added · "
     + ($deleted_files | tostring)
     + " deleted"
   else
     "No file details in this push."
   end)) as $files_summary

# Title: what actually happened to the ref.
| ((if $count == 1 then "1 commit" else ($count | tostring) + " commits" end)) as $count_phrase
| ((if ($event.deleted == true) then
     "Deleted " + $ref.kind + " `" + $ref_name + "`"
   elif ($ref.kind == "tag") then
     (if ($event.created == true) then "Published tag" else "Updated tag" end) + " `" + $ref_name + "`"
   elif ($event.created == true) then
     "Created branch `" + $ref_name + "` with " + $count_phrase
   elif ($event.forced == true) then
     "Force-pushed " + $count_phrase + " to `" + $ref_name + "`"
   elif $count == 0 then
     "Updated branch `" + $ref_name + "`"
   else
     "Pushed " + $count_phrase + " to `" + $ref_name + "`"
   end) | clamp(240)) as $title

# Description: the log, or one plain sentence when there is nothing to log.
| ((if ($event.deleted == true) then
     "Branch `" + $ref_name + "` was deleted from `" + $repo_name + "`."
   elif $count == 0 then
     "This push carried no commits."
   else
     ($commits | commit_log(3000; (if $count == 1 then 300 else 140 end); $repo_url))
   end) | clamp(4096)) as $description

# Footer: the human, next to Discord's own rendering of the timestamp.
| ((("Pushed by " + $actor_login) | clamp(1800))) as $footer
| (($event.head_commit.timestamp // $event.repository.pushed_at // "") | tostring) as $raw_stamp
| ((if ($raw_stamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}")) then
     $raw_stamp
   else
     (now | todateiso8601)
   end)) as $timestamp

# Accent colour. Garbage in the variable falls back to the neutral default
# rather than to a payload Discord rejects.
| ((env.DISCORD_EMBED_COLOR // "2829617") | tostring | gsub("[[:space:]]+"; "")) as $raw_color
| ((if ($raw_color | test("^[0-9]{1,8}$")) then ($raw_color | tonumber) else 2829617 end)) as $color

| {
    allowed_mentions: {parse: []},
    embeds: [
      {
        color: $color,
        author: (
          {name: ($repo_name | clamp(240)), url: $repo_url}
          + (if ($repo_icon // "") | length > 0 then {icon_url: $repo_icon} else {} end)
        ),
        title: $title,
        url: $target_url,
        description: $description,
        fields: (
          [
            {
              name: (if $ref.kind == "tag" then "Tag" else "Branch" end),
              value: (link("`" + $ref_name + "`"; $ref_url) | clamp(900)),
              inline: true
            },
            {
              name: "Commit",
              value: (
                (if ($sha | length) > 0 then
                   link("`" + ($sha | short_sha) + "`"; $commit_url)
                 else
                   "No commit in this push."
                 end) | clamp(900)
              ),
              inline: true
            }
          ]
          + (if $count > 0 then
               [{name: "Files", value: ($files_summary | clamp(900)), inline: true}]
             else
               []
             end)
        ),
        footer: {text: $footer},
        timestamp: $timestamp
      }
    ]
  }
