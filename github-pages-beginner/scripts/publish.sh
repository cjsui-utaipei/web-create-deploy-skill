#!/bin/bash
# macOS built-in Bash 3.2; no jq, Python, Node, gh or global git changes.
set +x
set -eu
umask 077
BASE=$(cd "$(dirname "$0")" && pwd)
PROJECT=.; NAME=; DRY=0; WAIT=90
while [ "$#" -gt 0 ]; do
 case "$1" in
 --project-dir) PROJECT=$2; shift 2;; --repo-name) NAME=$2; shift 2;;
 --dry-run) DRY=1; shift;; --wait-seconds) WAIT=$2; shift 2;;
 *) printf '{"ok":false,"code":"ARGUMENT_ERROR"}\n'; exit 1;; esac
done
fail() { printf '{"ok":false,"code":"%s"}\n' "$1"; exit 1; }
command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1 || fail GIT_MISSING
cd "$PROJECT" 2>/dev/null || fail PROJECT_MISSING
PROJECT=$(pwd -P)
WORKSPACE=$(dirname "$PROJECT")
[ "$(basename "$WORKSPACE")" = web-create-deploy ] || fail WORKSPACE_LAYOUT
[ "$(basename "$PROJECT")" != web-create-deploy ] || fail WORKSPACE_LAYOUT
[ ! -e github_pat.txt ] || fail TOKEN_INSIDE_SITE
TOKEN_FILE="$WORKSPACE/github_pat.txt"
[ -f "$TOKEN_FILE" ] || fail TOKEN_MISSING
[ ! -L "$TOKEN_FILE" ] || fail TOKEN_FILE_UNSAFE
TOKEN=$(LC_ALL=C sed $'1s/^\xef\xbb\xbf//' "$TOKEN_FILE" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
[ -n "$TOKEN" ] || fail TOKEN_EMPTY
case "$TOKEN" in *[!a-zA-Z0-9_]*) fail TOKEN_INVALID;; esac
[ -f index.html ] || fail SITE_ENTRY_MISSING
[ ! -L index.html ] || fail SITE_ENTRY_UNSAFE
[ -n "$NAME" ] || NAME=$(basename "$PROJECT" | LC_ALL=C tr '[:upper:] _' '[:lower:]--' | LC_ALL=C sed 's/[^a-z0-9-]//g;s/--*/-/g;s/^-//;s/-$//')
[ -n "$NAME" ] || NAME=my-webpage
case "$NAME" in *[!a-zA-Z0-9_-]*|-*|_*) fail REPO_NAME_INVALID;; esac
[ ${#NAME} -le 80 ] || fail REPO_NAME_INVALID
# Parent repositories and linked worktrees are deliberately not adopted.
if git rev-parse --show-toplevel >/dev/null 2>&1; then
 [ "$(git rev-parse --show-toplevel)" = "$PROJECT" ] && [ -d .git ] || fail REPO_CONFLICT
 [ "$(git symbolic-ref --short HEAD 2>/dev/null || true)" = main ] || fail REPO_CONFLICT
 [ -z "$(git diff --cached --name-only)" ] || fail STAGED_CHANGES
fi
TMP=$(mktemp -d "${TMPDIR:-/tmp}/pages-publish.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT TERM
printf '%s\n' "$TOKEN" > "$TMP/pattern"
json() {
 /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null || /usr/bin/osascript -l JavaScript "$BASE/json.js" "$1" "$2" 2>/dev/null || true
}
# Reject known secret paths in every reachable historical tree before any network mutation.
if [ -d .git ]; then
 git log --all --format= --name-only -z > "$TMP/history" 2>/dev/null || true
 while IFS= read -r -d '' secret_path; do
  printf '%s\n' "$secret_path" | LC_ALL=C grep -Eiq '(^|/)(github_pat[^/]*|\.env($|\.)|[^/]*\.(pem|key)$)' && fail SECRET_IN_HISTORY
 done < "$TMP/history"
 git config --local --list > "$TMP/config"
 grep -Fq -f "$TMP/pattern" "$TMP/config" && fail TOKEN_IN_CONFIG
 for rev in $(git rev-list --all); do
  git grep -q -F -f "$TMP/pattern" "$rev" -- && fail SECRET_IN_HISTORY
 done
fi
# Files are checked without printing contents or following symlinks.
find . -name .git -prune -o -type l -print > "$TMP/links"
[ ! -s "$TMP/links" ] || fail SYMLINK_UNSUPPORTED
find . -name .git -prune -o -type f -print0 > "$TMP/files"
while IFS= read -r -d '' f; do
 case "$f" in */github_pat.txt|*/.env|*/.env.*|*.pem|*.key) continue;; esac
 grep -Fq -f "$TMP/pattern" "$f" && fail SECRET_IN_FILES
 [ "$(stat -f %z "$f")" -lt 104857600 ] || fail FILE_TOO_LARGE
done < "$TMP/files"
if [ "$DRY" = 1 ]; then
 printf '{"ok":true,"action":"dry-run","repository":"%s","token_file_present":true,"gitignore_planned":true}\n' "$NAME"; exit 0
fi
printf 'Authorization: Bearer %s\nAccept: application/vnd.github+json\nX-GitHub-Api-Version: 2026-03-10\n' "$TOKEN" > "$TMP/headers"
api() {
 method=$1; endpoint=$2; payload=${3:-}
 if [ -n "$payload" ]; then
  printf '%s' "$payload" > "$TMP/request"
  HTTP=$(curl --silent --show-error --connect-timeout 15 --max-time 40 -X "$method" -H @"$TMP/headers" -D "$TMP/response-headers" -o "$TMP/response" -w '%{http_code}' --data-binary @"$TMP/request" "https://api.github.com$endpoint" 2>"$TMP/error") || fail NETWORK_ERROR
 else
  HTTP=$(curl --silent --show-error --connect-timeout 15 --max-time 40 -X "$method" -H @"$TMP/headers" -D "$TMP/response-headers" -o "$TMP/response" -w '%{http_code}' "https://api.github.com$endpoint" 2>"$TMP/error") || fail NETWORK_ERROR
 fi
 [ "$HTTP" != 401 ] || fail TOKEN_INVALID
 if [ "$HTTP" = 403 ] || [ "$HTTP" = 429 ]; then
  if grep -Eiq 'rate.limit|secondary rate|abuse' "$TMP/response" || grep -Eiq '^retry-after:|^x-ratelimit-remaining: 0' "$TMP/response-headers"; then fail RATE_LIMITED; fi
  fail TOKEN_PERMISSION
 fi
}
api GET /user
[ "$HTTP" = 200 ] || fail TOKEN_INVALID
LOGIN=$(json "$TMP/response" login); ID=$(json "$TMP/response" id)
case "$LOGIN" in ''|*[!a-zA-Z0-9-]*) fail API_RESPONSE_INVALID;; esac
case "$ID" in ''|*[!0-9]*) fail API_RESPONSE_INVALID;; esac
ACTION=created
if [ -f .git/pages-beginner-state ]; then
 read -r OWNER REPO < .git/pages-beginner-state
 [ "$OWNER" = "$LOGIN" ] || fail ACCOUNT_MISMATCH
 case "$REPO" in ''|*[!a-zA-Z0-9_-]*) fail REPO_CONFLICT;; esac
 ACTION=updated
else
 if [ -d .git ] && git remote get-url origin >/dev/null 2>&1; then fail UNMANAGED_REMOTE; fi
 REPO=$NAME; n=1
 while :; do
  api GET "/repos/$LOGIN/$REPO"
  [ "$HTTP" = 404 ] && break
  [ "$HTTP" = 200 ] || fail REPO_CREATE_FAILED
  n=$((n+1)); [ "$n" -le 30 ] || fail REPO_CONFLICT; REPO="$NAME-$n"
 done
fi
REMOTE="https://github.com/$LOGIN/$REPO.git"
if [ "$ACTION" = updated ]; then
 [ "$(git remote get-url origin 2>/dev/null)" = "$REMOTE" ] || fail REPO_CONFLICT
 api GET "/repos/$LOGIN/$REPO"
 [ "$HTTP" = 200 ] || fail REPO_CONFLICT
 [ "$(json "$TMP/response" private)" = false ] || fail REPO_CONFLICT
fi
# The helper contains no secret: it reads the token from a private temporary file.
printf '%s' "$TOKEN" > "$TMP/token"
cat > "$TMP/helper" <<'HELPER'
#!/bin/sh
[ "$1" = get ] || exit 0
protocol= host=
while IFS= read -r line && [ -n "$line" ]; do
 case "$line" in protocol=*) protocol=${line#protocol=};; host=*) host=${line#host=};; esac
done
[ "$protocol" = https ] && [ "$host" = github.com ] || exit 0
printf 'username=x-access-token\npassword='
cat "$(dirname "$0")/token"
printf '\n'
HELPER
chmod 700 "$TMP/helper"
authgit() { git -c credential.helper= -c "credential.helper=$TMP/helper" -c credential.interactive=false -c http.followRedirects=false "$@" > "$TMP/git-out" 2> "$TMP/git-error"; }
export GIT_TERMINAL_PROMPT=0
if [ "$ACTION" = updated ]; then
 authgit ls-remote --heads origin || fail GIT_PUSH_FAILED
 if [ -s "$TMP/git-out" ]; then
  grep -q 'refs/heads/main$' "$TMP/git-out" || fail REPO_CONFLICT
  authgit fetch origin main || fail GIT_PUSH_FAILED
  git merge-base --is-ancestor FETCH_HEAD HEAD || fail REMOTE_DIVERGED
 fi
fi
if [ ! -d .git ]; then git init -q || fail GIT_INIT_FAILED; git symbolic-ref HEAD refs/heads/main; fi
# Local backup, kept outside publication and preserved between runs.
BACKUP=".git/pages-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACKUP"
[ ! -f .gitignore ] || cp .gitignore "$BACKUP/gitignore"
touch .gitignore
for rule in github_pat.txt 'github_pat*' .env '.env.*' '*.pem' '*.key' .DS_Store .agents/ .codex/ node_modules/; do
 if ! grep -qxF "$rule" .gitignore; then
  [ ! -s .gitignore ] || [ "$(tail -c 1 .gitignore | od -An -tu1 | tr -d ' \n')" = 10 ] || printf '\n' >> .gitignore
  printf '%s\n' "$rule" >> .gitignore
 fi
done
touch .nojekyll
git config user.name "$LOGIN"
git config user.email "$ID+$LOGIN@users.noreply.github.com"
git add -A > "$TMP/add" 2>&1 || fail GIT_COMMIT_FAILED
git ls-files -z > "$TMP/tracked"
while IFS= read -r -d '' secret_path; do
 printf '%s\n' "$secret_path" | LC_ALL=C grep -Eiq '(^|/)(github_pat[^/]*|\.env($|\.)|[^/]*\.(pem|key)$)' && fail SECRET_STAGED
done < "$TMP/tracked"
if ! git diff --cached --quiet; then git commit -qm 'Publish or update website' > "$TMP/commit" 2>&1 || fail GIT_COMMIT_FAILED; else ACTION=unchanged; fi
SHA=$(git rev-parse HEAD)
git show HEAD:index.html > "$TMP/expected-site"
if [ ! -f .git/pages-beginner-state ]; then
 api POST /user/repos "{\"name\":\"$REPO\",\"private\":false,\"auto_init\":false}"
 [ "$HTTP" = 201 ] || fail REPO_CREATE_FAILED
 git remote add origin "$REMOTE" || fail REPO_CONFLICT
 printf '%s %s\n' "$LOGIN" "$REPO" > .git/pages-beginner-state
fi
authgit push -u origin main || fail GIT_PUSH_FAILED
api GET "/repos/$LOGIN/$REPO/pages"
if [ "$HTTP" = 404 ]; then
 api POST "/repos/$LOGIN/$REPO/pages" '{"build_type":"legacy","source":{"branch":"main","path":"/"}}'
 [ "$HTTP" = 201 ] || fail PAGES_CREATE_FAILED
elif [ "$HTTP" = 200 ]; then
 [ -z "$(json "$TMP/response" cname)" ] || fail CUSTOM_PAGES_CONFIG
 [ "$(json "$TMP/response" build_type)" != workflow ] || fail CUSTOM_PAGES_CONFIG
 if [ "$(json "$TMP/response" source.branch)" != main ] || [ "$(json "$TMP/response" source.path)" != / ]; then
  api PUT "/repos/$LOGIN/$REPO/pages" '{"source":{"branch":"main","path":"/"}}'
  [ "$HTTP" = 204 ] || fail PAGES_CONFIG_FAILED
 fi
else fail PAGES_CONFIG_FAILED; fi
URL="https://$LOGIN.github.io/$REPO/"
finish() { printf '{"ok":%s,"action":"%s","username":"%s","repository":"%s","repository_url":"https://github.com/%s/%s","pages_url":"%s","commit":"%s","pages_status":"%s","code":"%s"}\n' "$1" "$ACTION" "$LOGIN" "$REPO" "$LOGIN" "$REPO" "$URL" "$SHA" "$2" "$3"; }
case "$WAIT" in ''|*[!0-9]*) fail ARGUMENT_ERROR;; esac
end=$((SECONDS+WAIT))
while :; do
 api GET "/repos/$LOGIN/$REPO/pages/builds/latest"
 if [ "$HTTP" = 200 ] && [ "$(json "$TMP/response" commit)" = "$SHA" ]; then
  STATUS=$(json "$TMP/response" status)
  [ "$STATUS" != errored ] || fail PAGES_BUILD_FAILED
  if [ "$STATUS" = built ]; then
   # No Authorization header on public Pages requests, including redirects.
   CODE=$(curl --silent --location --proto '=https' --proto-redir '=https' --max-time 25 -o "$TMP/site" -w '%{http_code}' "$URL?verify=$SHA" 2>"$TMP/site-error") || CODE=000
   if [ "$CODE" = 200 ] && cmp -s "$TMP/expected-site" "$TMP/site"; then finish true built ''; exit 0; fi
  fi
 elif [ "$HTTP" != 200 ] && [ "$HTTP" != 404 ]; then fail PAGES_CONFIG_FAILED; fi
 [ "$SECONDS" -lt "$end" ] || { finish false pending PAGES_BUILD_PENDING; exit 2; }
 sleep 5
done
