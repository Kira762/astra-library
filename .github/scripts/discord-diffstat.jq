# Raw GitHub file entries -> the diffstat the Discord embed renders.
#
#   input   {"files": [{filename, additions, deletions} ...], "truncated": bool}
#           - the entries /compare returns (one per file) or /commits/<sha>
#             returns (one per commit, so the same path can arrive several
#             times). `truncated` says the caller already knows it is holding
#             only part of the picture.
#   output  {files: [{path, additions, deletions} ...], total_files,
#            total_additions, total_deletions, truncated}
#
# Run it on its own with:
#   jq -f .github/scripts/discord-diffstat.jq raw.json
#
# Two things this file decides:
#
#  1. The list is sorted by size - the file that moved 400 lines matters more
#     than the one that moved four - and capped, because the embed renders a
#     screenful of lines and every path past that costs a temp file, an env var
#     and a request nobody reads.
#  2. The totals are still summed over *every* file the API reported, cap or no
#     cap, so `+58 -21` stays true even when the list under it says
#     "… and 285 more". `total_files` is what came back, not what is shown.
#
# A path both added and removed inside one push nets out to 0/0 here; it stays
# in the list (a rename is worth seeing) and just carries no numbers.

# One API file object -> one row, whatever shape it arrived in.
def file_entry:
  {
    path: ((.filename // .path // "") | tostring),
    additions: ((.additions // 0) | if type == "number" then . else 0 end),
    deletions: ((.deletions // 0) | if type == "number" then . else 0 end)
  };

def max_files: 300;

(.files // []) as $raw
| [$raw[] | file_entry | select((.path | length) > 0)] as $entries

# A path touched by three commits is one file, changed this much in total.
| ($entries
   | group_by(.path)
   | map({
       path: .[0].path,
       additions: (map(.additions) | add // 0),
       deletions: (map(.deletions) | add // 0)
     })
   | sort_by([(- (.additions + .deletions)), .path])
  ) as $files
| ($files[0:max_files]) as $kept
| {
    files: $kept,
    total_files: ($files | length),
    total_additions: ([$files[].additions] | add // 0),
    total_deletions: ([$files[].deletions] | add // 0),
    truncated: ((.truncated // false) or (($files | length) > ($kept | length)))
  }
