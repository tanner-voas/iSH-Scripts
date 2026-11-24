#!/bin/sh
# POSIX shell + Git + standard BusyBox tools. First-parent source version tags.
set -eu
fail() { printf 'Tag operation refused: %s\n' "$*" >&2; exit 1; }
repo=.; rebuild=0; apply=0; prune=0; push_main=0; backup_dir=; plan_only=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo) [ "$#" -ge 2 ] || fail 'missing repo'; repo=$2; shift;;
        --rebuild) rebuild=1;; --apply) apply=1;; --prune-branches) prune=1;;
        --push-main) push_main=1;; --backup-dir) [ "$#" -ge 2 ] || fail 'missing backup directory'; backup_dir=$2; shift;;
        --local-plan) plan_only=1; rebuild=1;;
        *) fail "unknown option $1";;
    esac
    shift
done
repo=$(CDPATH= cd "$repo" && pwd -P); name=${repo##*/}
g() { git -C "$repo" "$@"; }
[ "$(g rev-parse --is-shallow-repository)" = false ] || fail 'full history required'
[ "$(g symbolic-ref --short HEAD)" = main ] || fail 'checkout main first'
status=$(g status --porcelain --untracked-files=no)
[ -z "$status" ] || fail 'tracked changes present'
[ "$apply" = 0 ] || [ "$rebuild" = 1 ] || [ "$prune" = 1 ] || fail '--apply needs cleanup mode'
[ "$push_main" = 0 ] || { [ "$rebuild" = 0 ] && [ "$prune" = 0 ]; } || fail 'cannot push main during cleanup'
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' 0; trap 'exit 1' 1 2 3 15
head=$(g rev-parse HEAD)
g rev-list --first-parent --reverse "$head" > "$tmp/history"
# A small JSON lexer: read only the top-level version string, never a nested
# dependency version or a quoted occurrence inside a description. Reject
# duplicate version keys and non-string version values. No jq/Python/Node.
version() {
    c=$1; v=
    if g show "$c:package.json" > "$tmp/package" 2>/dev/null; then
        v=$(awk '
        { s=s $0 "\n" }
        END {
          depth=0; key=""; expect=0; found=0; n=length(s)
          for(i=1;i<=n;i++) {
            ch=substr(s,i,1)
            if(ch=="\"") {
              tok=""; closed=0
              for(i++;i<=n;i++) {
                x=substr(s,i,1)
                if(x=="\\") { tok=tok x substr(s,++i,1); continue }
                if(x=="\"") { closed=1; break }
                tok=tok x
              }
              if(!closed) exit 2
              j=i+1; while(j<=n && substr(s,j,1)~/[[:space:]]/) j++
              if(depth==1 && expect) { value=tok; expect=0; found++; continue }
              if(depth==1 && substr(s,j,1)==":" && tok=="version") { i=j; expect=1 }
              continue
            }
            if(ch~/[[:space:]]/) continue
            if(expect) exit 2
            if(ch=="{" || ch=="[") depth++
            if(ch=="}" || ch=="]") depth--
            if(depth<0) exit 2
          }
          if(depth!=0 || expect || found>1) exit 2
          if(found==1) { if(value=="") exit 2; print value }
        }' "$tmp/package") || fail "invalid version metadata at $c"
    fi
    if [ -z "$v" ] && g show "$c:VERSION" > "$tmp/package" 2>/dev/null; then
        v=$(sed 's/^v//' "$tmp/package")
    fi
    if [ -n "$v" ]; then
        printf '%s\n' "$v" | awk 'NR==1 && /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/ {ok=1} END {exit !(ok && NR==1)}' || fail "invalid version at $c: $v"
        if [ "$c" = f785e58cc1675e63c820d57d8277d86851cbc94d ]; then
            [ "$v" = 1.1.11 ] || fail 'historical Ascendant correction mismatch'
            v=0.1.11
        fi
    fi
    printf '%s\n' "$v"
}
: > "$tmp/old"; : > "$tmp/branches"; : > "$tmp/localtags"
if [ "$plan_only" = 0 ]; then
    g ls-remote --refs origin 'refs/heads/*' 'refs/tags/*' > "$tmp/raw"
    sort -k2 "$tmp/raw" > "$tmp/remote"
    remote_main=$(awk '$2=="refs/heads/main" {print $1}' "$tmp/remote")
    [ -n "$remote_main" ] || fail 'origin/main missing'
    if [ "$push_main" = 1 ]; then g merge-base --is-ancestor "$remote_main" "$head" || fail 'main diverged; reconcile first'
    else [ "$head" = "$remote_main" ] || fail 'local main differs from origin/main; syncapp first'; fi
    awk '$2~/^refs\/tags\//' "$tmp/remote" > "$tmp/old"
    g for-each-ref --format='%(objectname) %(refname)' refs/tags/ > "$tmp/localtags"
    if [ "$prune" = 1 ]; then
        g ls-remote --symref origin HEAD > "$tmp/default"
        awk '$1=="ref:" && $2=="refs/heads/main" && $3=="HEAD" {ok=1} END {exit !ok}' "$tmp/default" || fail 'remote default must be main'
        awk -v name="$name" '$2~/^refs\/heads\// && $2!="refs/heads/main" && !(name=="AppLauncher" && $2=="refs/heads/production")' "$tmp/remote" > "$tmp/branches"
        g for-each-ref --format='%(objectname) %(refname)' refs/heads/ > "$tmp/allbranches"
        awk -v name="$name" '$2!="refs/heads/main" && !(name=="AppLauncher" && $2=="refs/heads/production")' "$tmp/allbranches" > "$tmp/localbranches"
        g worktree list --porcelain > "$tmp/worktrees"
        awk 'FILENAME==ARGV[1] {b[$2]=1;next} $1=="branch" && ($2 in b) {exit 1}' "$tmp/localbranches" "$tmp/worktrees" || fail 'non-main branch checked out elsewhere'
    fi
fi
# Validate existing revision tags in a single pass of main history. Determine
# the last tagged commit, per-version counters, and the untagged suffix.
: > "$tmp/counts"; : > "$tmp/cursor"
if [ "$rebuild" = 0 ]; then
    awk -v counts="$tmp/counts" -v cursor="$tmp/cursor" '
    function bad(m){print m > "/dev/stderr"; exit 1}
    FILENAME==ARGV[1] {
      ref=$2; sub(/^refs\/tags\//,"",ref)
      if(ref ~ /^v[0-9]+\.[0-9]+\.[0-9]+\.r[1-9][0-9]*$/) {
        v=ref; sub(/^v/,"",v); sub(/\.r[0-9]+$/,"",v)
        r=ref; sub(/^.*\.r/,"",r)
        if($1 in ver) bad("multiple revision tags on " $1)
        ver[$1]=v; rev[$1]=r+0; total++
      } else if(ref~/^v[0-9]+\.[0-9]+\.[0-9]+$/) {sub(/^v/,"",ref);base[ref]=$1; bases++}
      else bad("legacy tag found; explicit --rebuild required: " ref)
      next
    }
    FILENAME==ARGV[2] {
      if($1 in ver) {
        if(gap) bad("gap in revision tags; explicit --rebuild required")
        v=ver[$1]; n=++num[v]; if(n!=rev[$1]) bad("revision sequence mismatch")
        if(n==1 && base[v]!=$1) bad("base tag mismatch for " v)
        last=$1; lv=v; seen++; started=1
      } else if(started) gap=1
    }
    END {
      if(seen!=total) bad("revision tag outside main history")
      for(v in base) if(!(v in num)) bad("base tag missing revision history: " v)
      for(v in num) print v,num[v] > counts
      if(last!="") print last,lv > cursor
    }' "$tmp/old" "$tmp/history" || fail 'existing tag history is inconsistent'
    # Refuse conflicting local tags; a local-only tag will never be pushed.
    awk 'FILENAME==ARGV[1]{r[$2]=$1;next} ($2 in r) && r[$2]!=$1{exit 1}' "$tmp/old" "$tmp/localtags" || fail 'local tag differs from origin; run explicit rebuild'
fi
if [ -s "$tmp/cursor" ]; then
    read -r cursor cv < "$tmp/cursor"
    [ "$(version "$cursor")" = "$cv" ] || fail 'revision cursor version mismatch'
    awk -v c="$cursor" 'seen{print} $1==c{seen=1}' "$tmp/history" > "$tmp/suffix"
else cp "$tmp/history" "$tmp/suffix"; fi
: > "$tmp/versions"
while IFS= read -r commit; do
    v=$(version "$commit") || exit 1
    printf '%s %s\n' "$commit" "${v:--}" >> "$tmp/versions"
done < "$tmp/suffix"
awk 'FILENAME==ARGV[1]{n[$1]=$2;started=1;next}
    $2=="-" {if(started){print "Version missing after first versioned commit: " $1 > "/dev/stderr";exit 1} next}
    {started=1; k=++n[$2]; if(k==1) print $1,"refs/tags/v" $2; print $1,"refs/tags/v" $2 ".r" k}' "$tmp/counts" "$tmp/versions" > "$tmp/new" || fail 'invalid version sequence'
if [ "$plan_only" = 1 ]; then sort -k2 "$tmp/new"; exit 0; fi
if [ "$rebuild" = 0 ]; then
    awk 'FILENAME==ARGV[1]{r[$2]=$1;next} ($2 in r) && r[$2]!=$1{exit 1}' "$tmp/new" "$tmp/localtags" || fail 'local tag conflicts with planned revision; run explicit rebuild'
fi
if [ "$rebuild" = 1 ]; then
    awk 'FILENAME==ARGV[1]{r[$2]=$1;next} !($2 in r){print}' "$tmp/new" "$tmp/old" > "$tmp/deletes"
else : > "$tmp/deletes"; fi
cat "$tmp/branches" >> "$tmp/deletes"
awk 'FILENAME==ARGV[1]{r[$2]=$1;next} r[$2]!=$1{print $1,$2,(($2 in r)?r[$2]:"-")}' "$tmp/old" "$tmp/new" > "$tmp/changes"
printf '%s: scanned %s commits; %s tag changes; %s remote refs to delete\n' "$name" "$(wc -l < "$tmp/suffix" | tr -d ' ')" "$(wc -l < "$tmp/changes" | tr -d ' ')" "$(wc -l < "$tmp/deletes" | tr -d ' ')"
if [ "$rebuild" = 1 ] || [ "$prune" = 1 ]; then
    if [ "$apply" = 0 ]; then cat "$tmp/changes" "$tmp/deletes"; echo 'Dry run; add --apply to execute.'; exit 0; fi
    folder=${backup_dir:-$(dirname "$repo")/git-ref-backups}; mkdir -p "$folder"; folder=$(CDPATH= cd "$folder" && pwd -P)
    stamp=$(date -u +%Y%m%dT%H%M%SZ)-$$; ns=refs/cleanup-backup/$stamp
    g fetch --no-tags --no-recurse-submodules origin "+refs/heads/*:$ns/heads/*" "+refs/tags/*:$ns/tags/*"
    bundle=$folder/$name-$stamp.bundle
    g bundle create "$bundle" --all; g bundle verify "$bundle"
    g for-each-ref --format='%(refname)' "$ns" > "$tmp/backuprefs"
    while IFS= read -r ref; do g update-ref -d "$ref"; done < "$tmp/backuprefs"
    g ls-remote --refs origin 'refs/heads/*' 'refs/tags/*' > "$tmp/raw"
    sort -k2 "$tmp/raw" > "$tmp/check"
    cmp -s "$tmp/remote" "$tmp/check" || fail 'remote refs changed during backup; rerun cleanup'
fi
set -- --atomic
while read -r sha ref old; do [ "$old" != - ] || old=; set -- "$@" "--force-with-lease=$ref:$old"; done < "$tmp/changes"
while read -r sha ref; do set -- "$@" "--force-with-lease=$ref:$sha"; done < "$tmp/deletes"
set -- "$@" origin
n=0
while read -r sha ref old; do set -- "$@" "$sha:$ref"; n=$((n+1)); done < "$tmp/changes"
while read -r sha ref; do set -- "$@" ":$ref"; n=$((n+1)); done < "$tmp/deletes"
if [ "$push_main" = 1 ] && [ "$head" != "$remote_main" ]; then set -- "$@" "$head:refs/heads/main"; n=$((n+1)); fi
if [ "$n" -gt 0 ]; then g -c push.followTags=false push "$@"; fi
# Exact remote tag sync after success; no force fetch in normal mode.
g ls-remote --refs origin 'refs/tags/*' > "$tmp/final"
if [ "$rebuild" = 1 ]; then
    awk 'FILENAME==ARGV[1]{r[$2]=1;next} !($2 in r){print}' "$tmp/final" "$tmp/localtags" > "$tmp/localdelete"
    while read -r sha ref; do g update-ref -d "$ref" "$sha"; done < "$tmp/localdelete"
fi
awk 'FILENAME==ARGV[1]{r[$2]=$1;next} r[$2]!=$1{print $2}' "$tmp/localtags" "$tmp/final" > "$tmp/fetch"
set -- --no-tags --no-recurse-submodules origin
n=0
while IFS= read -r ref; do prefix=; [ "$rebuild" = 0 ] || prefix=+; set -- "$@" "$prefix$ref:$ref"; n=$((n+1)); done < "$tmp/fetch"
if [ "$n" -gt 0 ]; then g fetch "$@"; fi
if [ "$prune" = 1 ]; then
    while read -r sha ref; do g branch -D "${ref#refs/heads/}"; done < "$tmp/localbranches"
    g fetch --no-tags --no-recurse-submodules --prune origin
fi
printf '%s: tags synchronized\n' "$name"
