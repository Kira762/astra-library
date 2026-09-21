# GitHub `push` event -> Discord webhook payload.
#
#   input   the event payload GitHub hands the workflow ($GITHUB_EVENT_PATH)
#   output  one JSON object, ready to POST to a Discord webhook URL
#   env     DISCORD_EMBED_COLOR      decimal accent colour, default 2829617
#           DISCORD_DIFFSTAT_JSON    optional. The per-file line counts that
#                                    discord-diffstat.sh collected, as one
#                                    compact JSON string. Without it the paths
#                                    in the event are still listed, just
#                                    without their +24 -9.
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
#   fields       Branch | Commit | Changes, inline, one row of three
#   files        a fenced block of `path +24 -9` lines, biggest change first,
#                ending in a count of the files that did not fit
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

# --- per-file churn ----------------------------------------------------------

# A line count with its sign. Zero, or a number the API never reported, shows
# as nothing at all: a rename or a binary file would otherwise print `+0 -0`,
# and a column of zeroes reads worse than a column of blanks.
def churn($value; $sign):
  if (($value | type) == "number") and $value > 0
  then ($sign + ($value | tostring))
  else ""
  end;

def pad_right($text; $width): $text + (" " * ([$width - ($text | length), 0] | max));
def pad_left($text; $width): (" " * ([$width - ($text | length), 0] | max)) + $text;

# Git allows almost anything in a file name, and this block is a fence with one
# line per file in it. A newline would forge a line, and a backtick could close
# the fence early - so both are flattened before the path is ever printed. The
# same rule as the commit log: nothing from Git reaches Discord as it came.
def clean_path: (tostring) | gsub("[[:cntrl:]]"; " ") | gsub("`"; "'");

# When a path is too long for its column the tail is what survives: the file
# name says more about which file changed than the top directory does.
def fit_path($path; $width):
  if ($path | length) <= $width then $path
  elif $width <= 1 then $path[0:$width]
  else "…" + $path[-($width - 1):]
  end;

# One line: the path, then the counts right-aligned so the signs line up down
# the block, and a file that only grew shown as `+24` rather than `+24 -0`.
def diffstat_line($path_width; $add_width; $del_width):
  ((.path | clean_path)) as $path
  | (churn(.additions; "+")) as $add
  | (churn(.deletions; "-")) as $del
  | pad_right(fit_path($path; $path_width); $path_width)
    + " " + pad_left($add; $add_width)
    + " " + pad_left($del; $del_width)
  | gsub("[ ]+$"; "");

# The block: biggest change first, inside a fence, and with a last line that
# counts what did not fit instead of dropping it. Two ceilings, not one - the
# line budget keeps a twelve-file push from turning into a wall of text, the
# character budget keeps a fourteen-file push with long paths inside the 1024
# a field is allowed.
def diffstat_block($files; $max_lines; $budget):
  ($files | sort_by([(- ((.additions // 0) + (.deletions // 0))), .path])) as $sorted
  | ($sorted[0:$max_lines]) as $shown
  | ([$shown[] | (.path | clean_path | length)] | max // 0) as $widest_path
  | ([$widest_path, 44] | min) as $path_width
  | ([$shown[] | churn(.additions; "+") | length] | max // 1) as $add_width
  | ([$shown[] | churn(.deletions; "-") | length] | max // 1) as $del_width
  | ($shown | map(diffstat_line($path_width; $add_width; $del_width))) as $lines
  | (reduce $lines[] as $line
      ({kept: [], used: 0, dropped: 0};
       ($line | length) as $length
       | ((if (.kept | length) > 0 then 1 else 0 end) + $length) as $cost
       | if (.dropped == 0) and ((.used + $cost) <= $budget) then
           .kept += [$line] | .used += $cost
         else
           .dropped += 1
         end))
  | (.dropped + (($sorted | length) - ($shown | length))) as $dropped
  | (.kept
     + (if $dropped > 0
        then ["… and " + ($dropped | tostring) + " more file(s)"]
        else []
        end))
  | join("\n")
  | "```\n" + . + "\n```";

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

# File churn. The line counts come from the workflow (discord-diffstat.sh):
# GitHub's push payload carries the paths a commit touched but never how much
# of them, so a notification that wants `README.md +24 -9` has to ask the API.
# It arrives as JSON in the environment rather than through --slurpfile, so the
# filter still runs on its own against a plain event file.
| ((env.DISCORD_DIFFSTAT_JSON // "")
   | if length > 0 then (try fromjson catch null) else null end) as $diffstat
| (($diffstat.files // [])
   | map(select(((.path // "") | length) > 0))) as $counted_files
| (($counted_files | length) > 0) as $counts_known

# Without counts the event's own file lists still say which files moved - worth
# more than the sentence this block used to post in their place. A deleted ref
# is the exception: its commits are not changes to the repository any more, and
# "Deleted branch x" does not need a diff.
| (if $counts_known then
     $counted_files
   elif $event.deleted != true then
     ([$commits[] | ((.added // [])[]), ((.removed // [])[]), ((.modified // [])[])]
      | unique | sort
      | map({path: ., additions: null, deletions: null}))
   else
     []
   end) as $changed_files

# Totals are summed by discord-diffstat.jq over every file the API reported,
# including the ones past the end of the list, so they can out-run the block.
| ((if $counts_known then ($diffstat.total_additions // ([$counted_files[].additions] | add // 0)) else 0 end)) as $total_add
| ((if $counts_known then ($diffstat.total_deletions // ([$counted_files[].deletions] | add // 0)) else 0 end)) as $total_del
| ((if $counts_known then ($diffstat.total_files // ($counted_files | length)) else 0 end)) as $total_files

# The inline tally, and the block it counts down from. `(partial)` is the API
# admitting it could not see the whole push: /compare stops at 300 files, and a
# commit whose diff never arrived is a commit whose lines are not in the total.
| (if $counts_known then
     ("+" + ($total_add | tostring) + " -" + ($total_del | tostring))
     + "\n"
     + ($total_files | tostring)
     + (if $total_files == 1 then " file" else " files" end)
     + (if ($diffstat.truncated // false) then " (partial)" else "" end)
   else
     null
   end) as $changes_text
| (if ($changed_files | length) > 0 then
     diffstat_block($changed_files; 15; 880)
   else
     null
   end) as $files_block

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
          + (if $counts_known then
               (if $changes_text != null
                then [{name: "Changes", value: $changes_text, inline: true}]
                else []
                end)
               + (if $files_block != null
                then [{name: "Files changed", value: ($files_block | clamp(1024)), inline: false}]
                else []
                end)
             elif ($event.deleted != true and ($changed_files | length) > 0) then
               [{
                 name: "Files",
                 value: ((($changed_files | length) | tostring)
                   + (if ($changed_files | length) == 1 then " file" else " files" end)
                   + " · "
                   + (([$commits[] | (.added // [])[]] | unique | length) | tostring)
                   + " added · "
                   + (([$commits[] | (.removed // [])[]] | unique | length) | tostring)
                   + " deleted"),
                 inline: true
               }]
             else
               []
             end)
        ),
        footer: {text: $footer},
        timestamp: $timestamp
      }
    ]
  }
