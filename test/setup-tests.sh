#!/bin/sh
# Tests for scripts/gitstalk-setup.sh and the "Env vars" git configuration, against
# fake-gitstalk.mjs. Everything runs in a throwaway HOME with its own git config, its own
# ssh-agents and throwaway keys; the person's own agent, keys, keychain and git config are
# never read or written (GIT_CONFIG_NOSYSTEM, GITSTALK_CREDENTIAL_HELPER=store).
#
#   sh setup-tests.sh                    starts the fake server itself (needs node)
#   GITSTALK_TEST_SERVER=http://host:port sh setup-tests.sh
#                                        uses a server started elsewhere (Linux containers)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SETUP=$HERE/../scripts/gitstalk-setup.sh
# Unix socket paths must stay short (104 bytes on macOS), so the sandbox lives under /tmp.
ROOT=$(mktemp -d /tmp/bst.XXXXXX)
PASSED=0
FAILED=0
AGENTS=

cleanup() {
  for pid in $AGENTS; do kill "$pid" 2>/dev/null; done
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null
  rm -rf "$ROOT"
}
trap cleanup EXIT INT TERM

export HOME="$ROOT/h"
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export XDG_CONFIG_HOME="$HOME/.config"
export GITSTALK_CREDENTIAL_HELPER=store
export BROWSER="$ROOT/fake-browser"
export GIT_TERMINAL_PROMPT=0
unset SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION DISPLAY WAYLAND_DISPLAY GITSTALK_NO_BROWSER
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
: >"$GIT_CONFIG_GLOBAL"
git config --global user.name test
git config --global user.email test@example.invalid
git config --global init.defaultBranch main
printf '#!/bin/sh\nprintf "%%s\\n" "$1" >>"%s/browser.log"\n' "$ROOT" >"$BROWSER"
chmod +x "$BROWSER"

pass() { PASSED=$((PASSED + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/     /'; }
check() { if eval "$2"; then pass "$1"; else fail "$1" "${3:-}"; fi; }

start_agent() {
  eval "$(ssh-agent -s -a "$1")" >/dev/null
  AGENTS="$AGENTS $SSH_AGENT_PID"
  unset SSH_AGENT_PID
}

fingerprint() { ssh-keygen -lf "$1" | awk '{print $2}'; }

# --- the fake Gitstalk --------------------------------------------------------------------
if [ -n "${GITSTALK_TEST_SERVER:-}" ]; then
  export GITSTALK_WEB=$GITSTALK_TEST_SERVER
else
  mkdir -p "$ROOT/repos/smoke"
  git init -q --bare "$ROOT/repos/smoke/demo.git"
  git clone -q "$ROOT/repos/smoke/demo.git" "$ROOT/seed" 2>/dev/null
  (cd "$ROOT/seed" && echo hi >README && git add README && git commit -qm init && git push -q origin HEAD:main)
  node "$HERE/fake-gitstalk.mjs" 0 "$ROOT/repos" >"$ROOT/port" &
  SERVER_PID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$ROOT/port" ] && break; sleep 0.2; done
  export GITSTALK_WEB="http://127.0.0.1:$(cat "$ROOT/port")"
fi
curl -fsS -X POST "$GITSTALK_WEB/__mode" >/dev/null || { echo "fake server unreachable at $GITSTALK_WEB"; exit 1; }
ORIGIN=$GITSTALK_WEB
HOST=${ORIGIN#*://}

# --- keys: a file key, a "1Password" agent, and a plain ssh-agent --------------------------
ssh-keygen -q -t ed25519 -N '' -C file-key -f "$HOME/.ssh/id_ed25519"
ssh-keygen -q -t ed25519 -N '' -C onepassword-key -f "$ROOT/op_key"
ssh-keygen -q -t ecdsa -b 256 -N '' -C agent-key -f "$ROOT/agent_key"
case $(uname -s) in
  Darwin) OP_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ;;
  *) OP_SOCK="$HOME/.1password/agent.sock" ;;
esac
mkdir -p "$(dirname "$OP_SOCK")"
start_agent "$OP_SOCK"
SSH_AUTH_SOCK=$OP_SOCK ssh-add -q "$ROOT/op_key" 2>/dev/null
start_agent "$ROOT/agent.sock"
export SSH_AUTH_SOCK="$ROOT/agent.sock"
ssh-add -q "$ROOT/agent_key" 2>/dev/null

check 'no credential helper is configured before setup (nothing can reach a real store)' \
  '[ -z "$(git config --get-all credential.helper)" ]'

# --- detect --------------------------------------------------------------------------------
out=$(sh "$SETUP" detect 2>&1)
tab=$(printf '\t')
check 'detect lists the 1Password agent key' \
  'printf "%s\n" "$out" | grep -q "^option${tab}1password${tab}$(fingerprint "$ROOT/op_key.pub")${tab}ssh-ed25519${tab}onepassword-key"' "$out"
check 'detect lists the ssh-agent key' \
  'printf "%s\n" "$out" | grep -q "^option${tab}ssh-agent${tab}$(fingerprint "$ROOT/agent_key.pub")${tab}ecdsa-sha2-nistp256"' "$out"
check 'detect lists ~/.ssh key files' \
  'printf "%s\n" "$out" | grep -q "^option${tab}file${tab}$(fingerprint "$HOME/.ssh/id_ed25519.pub")${tab}.*${tab}$HOME/.ssh/id_ed25519.pub"' "$out"
check 'detect offers to generate a key' 'printf "%s\n" "$out" | grep -q "^option${tab}generate"' "$out"
check 'detect reports ssh-keygen and the git origin' \
  'printf "%s\n" "$out" | grep -q "^ssh_keygen: yes" && printf "%s\n" "$out" | grep -q "^git_origin: $ORIGIN"' "$out"
out=$(env -u GITSTALK_WEB BEANSTALK_WEB="$GITSTALK_WEB" sh "$SETUP" detect 2>&1)
check 'the setting names from before the rename still work (BEANSTALK_WEB)' \
  'printf "%s\n" "$out" | grep -q "^git_origin: $ORIGIN"' "$out"

# --- generate ------------------------------------------------------------------------------
out=$(sh "$SETUP" generate 2>&1)
check 'generate makes ~/.ssh/gitstalk_ed25519 with a gitstalk comment' \
  '[ -f "$HOME/.ssh/gitstalk_ed25519" ] && grep -q "gitstalk " "$HOME/.ssh/gitstalk_ed25519.pub"' "$out"
check 'generate refuses to overwrite a key' '! sh "$SETUP" generate >/dev/null 2>&1'

# --- register through the browser ----------------------------------------------------------
# A desktop session (on Linux a browser needs a display; without one setup shows a code).
out=$(DISPLAY=:0 sh "$SETUP" register --key "$HOME/.ssh/gitstalk_ed25519.pub" 2>&1)
status=$?
check 'register (browser) is approved and stores the HTTPS token' \
  '[ $status -eq 0 ] && printf "%s\n" "$out" | grep -q "^approved: key added to @smoke" && printf "%s\n" "$out" | grep -q "^https_token: stored"' "$out"
check 'register opened the approval page with the code' 'grep -q "/settings/keys/add?code=BCDF-GHJK" "$ROOT/browser.log"'
check 'register never prints the token' '! printf "%s\n" "$out" | grep -q "bsu_"' "$out"
state=$(curl -fsS "$GITSTALK_WEB/__state")
check 'register sent only the public key, the machine name and asked for a token' \
  'printf "%s" "$state" | grep -q "\"public_key\":\"$(cut -d" " -f1-2 "$HOME/.ssh/gitstalk_ed25519.pub")" && printf "%s" "$state" | grep -q "\"https_token\":true" && ! printf "%s" "$state" | grep -q PRIVATE' "$state"
helpers=$(git config --get-all "credential.$ORIGIN/.helper" | tr '\n' ',')
check 'the credential helper is scoped to the Gitstalk host only (reset, then store)' \
  '[ "$helpers" = ",store," ] && [ -z "$(git config --get-all credential.helper)" ]' "$helpers"
check 'the token sits in git-credentials (0600), for this host only' \
  '[ "$(ls -l "$HOME/.git-credentials" | cut -c1-10)" = "-rw-------" ] && grep -q "@${HOST%%:*}" "$HOME/.git-credentials"'

# --- verify, clone, remote -----------------------------------------------------------------
out=$(sh "$SETUP" verify smoke/demo 2>&1)
check 'verify names the account and reaches the repository' \
  'printf "%s\n" "$out" | grep -q "^whoami: @smoke" && printf "%s\n" "$out" | grep -q "^ls_remote: smoke/demo ok"' "$out"
out=$(cd "$ROOT" && sh "$SETUP" remote smoke/demo "$ROOT/clone" 2>&1)
check 'remote clones over HTTPS without a prompt' '[ -f "$ROOT/clone/README" ]' "$out"
out=$(cd "$ROOT/clone" && git remote set-url origin https://example.invalid/x.git && sh "$SETUP" remote smoke/demo 2>&1)
check 'remote points an existing clone back at Gitstalk' \
  '[ "$(git -C "$ROOT/clone" remote get-url origin)" = "$ORIGIN/smoke/demo.git" ]' "$out"
out=$(cd "$ROOT/clone" && git switch -q -c "bean/x$$" && echo more >>README && git commit -qam more && git push -q origin "bean/x$$" 2>&1)
status=$?
check 'git push uses the stored credential silently' '[ $status -eq 0 ]' "$out"

# --- custom host: the saved host, GITSTALK_WEB over it, the MCP line ------------------------
HOST_FILE="$XDG_CONFIG_HOME/gitstalk/host"
out=$(sh "$SETUP" detect 2>&1)
check 'detect says which web app it uses and why (GITSTALK_WEB)' \
  'printf "%s\n" "$out" | grep -qx "web: $ORIGIN (GITSTALK_WEB)"' "$out"
check 'detect prints one mcp line naming /gitstalk:host for a non-production MCP server' \
  '[ "$(printf "%s\n" "$out" | grep -c "^mcp: ")" -eq 1 ] && printf "%s\n" "$out" | grep -qF "mcp: this host'"'"'s MCP server is $ORIGIN/mcp; in Claude Code run /gitstalk:host $ORIGIN (then restart Claude Code and run /mcp to sign in)"' "$out"
out=$(sh "$SETUP" verify 2>&1)
check 'verify prints the same mcp line' 'printf "%s\n" "$out" | grep -q "^mcp: this host.s MCP server is $ORIGIN/mcp"' "$out"
curl -fsS -X POST "$GITSTALK_WEB/__mode?mcp=https://mcp.gitstalk.io/mcp" >/dev/null
out=$(sh "$SETUP" detect 2>&1; sh "$SETUP" verify 2>&1)
check 'detect and verify stay silent about MCP when it is the production server' \
  '! printf "%s\n" "$out" | grep -q "^mcp"' "$out"
curl -fsS -X POST "$GITSTALK_WEB/__mode" >/dev/null
out=$(env -u GITSTALK_WEB sh "$SETUP" host "$ORIGIN/" 2>&1)
status=$?
check 'host URL checks the host, saves it and prints the Claude Code configure line' \
  '[ $status -eq 0 ] && [ "$(cat "$HOST_FILE")" = "$ORIGIN" ] && printf "%s\n" "$out" | grep -qx "host: saved $ORIGIN in $HOST_FILE" && printf "%s\n" "$out" | grep -qxF "claude_code: printf '"'"'%s'"'"' '"'"'{\"mcp_url\":\"$ORIGIN/mcp\"}'"'"' | claude plugin configure gitstalk@gitstalk --values-stdin"' "$out"
out=$(env -u GITSTALK_WEB sh "$SETUP" detect 2>&1)
check 'without GITSTALK_WEB, detect follows the saved host and no longer repeats the mcp line' \
  'printf "%s\n" "$out" | grep -qx "web: $ORIGIN (saved in $HOST_FILE)" && printf "%s\n" "$out" | grep -q "^git_origin: $ORIGIN" && ! printf "%s\n" "$out" | grep -q "^mcp:"' "$out"
out=$(env -u GITSTALK_WEB sh "$SETUP" verify smoke/demo 2>&1)
check 'verify follows the saved host' 'printf "%s\n" "$out" | grep -q "^ls_remote: smoke/demo ok"' "$out"
out=$(cd "$ROOT/clone" && git remote set-url origin https://example.invalid/x.git && env -u GITSTALK_WEB sh "$SETUP" remote smoke/demo 2>&1)
check 'remote follows the saved host' '[ "$(git -C "$ROOT/clone" remote get-url origin)" = "$ORIGIN/smoke/demo.git" ]' "$out"
out=$(GITSTALK_WEB=http://127.0.0.1:9 sh "$SETUP" detect 2>&1)
check 'GITSTALK_WEB wins over the saved host' 'printf "%s\n" "$out" | grep -q "cannot reach http://127.0.0.1:9"' "$out"
out=$(env -u GITSTALK_WEB sh "$SETUP" host http://127.0.0.1:9 2>&1)
check 'host refuses a host that does not answer and keeps the saved one' \
  '[ "$(cat "$HOST_FILE")" = "$ORIGIN" ] && printf "%s\n" "$out" | grep -q "cannot reach http://127.0.0.1:9"' "$out"
check 'host refuses something that is not a URL' '! sh "$SETUP" host gitstalk.dev >/dev/null 2>&1'
out=$(sh "$SETUP" host --reset 2>&1)
check 'host --reset forgets the saved host (back to https://gitstalk.io)' \
  '[ ! -e "$HOST_FILE" ] && printf "%s\n" "$out" | grep -q "^host: forgotten; https://gitstalk.io"' "$out"

# --- create: POST /api/repos with the stored token, then the remote --------------------------
# curl and git are wrapped to log their arguments, so the token can be shown never to be in argv.
mkdir -p "$ROOT/bin"
for tool in curl git; do
  real=$(command -v "$tool")
  printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >>"%s/argv.log"\nexec "%s" "$@"\n' "$tool" "$ROOT" "$real" >"$ROOT/bin/$tool"
  chmod +x "$ROOT/bin/$tool"
done
: >"$ROOT/argv.log"
# Runs the setup script with the wrappers first on PATH, from DIR; keeps every output line.
create_in() {
  dir=$1
  shift
  out=$(cd "$dir" && PATH="$ROOT/bin:$PATH" sh "$SETUP" create "$@" 2>&1)
  status=$?
  printf '%s\n' "$out" >>"$ROOT/create.out"
}
TOKEN=$(printf 'protocol=%s\nhost=%s\n\n' "${ORIGIN%%://*}" "$HOST" | git credential fill | sed -n 's/^password=//p')
NEW="new-$(date +%s)-$$"
mkdir -p "$ROOT/newrepo" && git -C "$ROOT/newrepo" init -q
(cd "$ROOT/newrepo" && echo first >README && git add README && git commit -qm 'Start the project')
create_in "$ROOT/newrepo" "smoke/$NEW" --description 'a "quoted" test'
check 'create (201) prints the new repository, private, and its web page' \
  '[ $status -eq 0 ] && printf "%s\n" "$out" | grep -q "^created: smoke/$NEW (private)$" && printf "%s\n" "$out" | grep -q "^web: $ORIGIN/smoke/$NEW$"' "$out"
check 'create then points origin at the new repository' \
  '[ "$(git -C "$ROOT/newrepo" remote get-url origin)" = "$ORIGIN/smoke/$NEW.git" ]' "$out"
state=$(curl -fsS "$GITSTALK_WEB/__state")
check 'create sent the stored token as a Bearer, private by default, with the description' \
  'printf "%s" "$state" | grep -q "\"name\":\"$NEW\",\"owner\":\"smoke\",\"visibility\":\"private\",\"description\":\"a \\\\\"quoted\\\\\" test\",\"bearer\":true,\"authorized\":true"' "$state"
out2=$(cd "$ROOT/newrepo" && git push -q origin HEAD:refs/heads/bean/first 2>&1)
status=$?
check 'the first commit pushes to the new repository as a bean' '[ $status -eq 0 ]' "$out2"
create_in "$ROOT/newrepo" "smoke/$NEW"
check 'create (409) says it exists and still connects the remote' \
  '[ $status -eq 0 ] && printf "%s\n" "$out" | grep -q "^exists: smoke/$NEW already exists" && printf "%s\n" "$out" | grep -q "^remote: origin is $ORIGIN/smoke/$NEW.git"' "$out"
create_in "$ROOT" "someorg/x$$" --public
check 'create (403) fails, names the namespace and the create scope' \
  '[ $status -ne 0 ] && printf "%s\n" "$out" | grep -q "not allowed to create someorg/x$$" && printf "%s\n" "$out" | grep -q "create scope"' "$out"
state=$(curl -fsS "$GITSTALK_WEB/__state")
check 'create --public asks for a public repository' \
  'printf "%s" "$state" | grep -q "\"name\":\"x$$\",\"owner\":\"someorg\",\"visibility\":\"public\""' "$state"
create_in "$ROOT" smoke/.bad
check 'create (422) fails and says the name is invalid' \
  '[ $status -ne 0 ] && printf "%s\n" "$out" | grep -q "invalid repository name .bad"' "$out"
mkdir -p "$ROOT/bare" && git -C "$ROOT/bare" init -q
create_in "$ROOT/bare" "b$$" --start empty
check 'create NAME without an owner creates it under the person, with the starter' \
  'printf "%s\n" "$out" | grep -q "^created: smoke/b$$ (private)" && curl -fsS "$GITSTALK_WEB/__state" | grep -q "\"name\":\"b$$\",\"owner\":\"smoke\",\"visibility\":\"private\",\"start\":\"empty\""' "$out"
check 'the token is in no command line and no output of create' \
  '[ -n "$TOKEN" ] && grep -q "^curl .*/api/repos" "$ROOT/argv.log" && ! grep -qF "$TOKEN" "$ROOT/argv.log" "$ROOT/create.out" && ! grep -q "bsu_" "$ROOT/argv.log" "$ROOT/create.out"' "$(cat "$ROOT/argv.log")"
out=$(cd "$ROOT" && GITSTALK_CREDENTIAL_HELPER= HOME="$ROOT/nobody" GIT_CONFIG_GLOBAL=/dev/null sh "$SETUP" create smoke/none 2>&1)
status=$?
check 'create without a stored credential says to run register' \
  '[ $status -ne 0 ] && printf "%s\n" "$out" | grep -q "run register"' "$out"
state=$(curl -fsS "$GITSTALK_WEB/__state")
check 'register asks for the create scope with read and write' \
  'printf "%s" "$state" | grep -q "\"scopes\":\[\"read\",\"write\",\"create\"\]"' "$state"

# --- register from the agent without a browser, deny, headless -----------------------------
: >"$ROOT/browser.log"
out=$(sh "$SETUP" register --agent-key "$(fingerprint "$ROOT/agent_key.pub")" --no-browser 2>&1)
check 'register --no-browser shows the page and code to enter on another device' \
  'printf "%s\n" "$out" | grep -q "open $ORIGIN/settings/keys/add and enter BCDF-GHJK" && [ ! -s "$ROOT/browser.log" ]' "$out"
out=$(SSH_CONNECTION='10.0.0.1 1 10.0.0.2 22' sh "$SETUP" register --agent-key "$(fingerprint "$ROOT/op_key.pub")" --agent "$OP_SOCK" 2>&1)
check 'over SSH (headless) the browser is not opened' \
  '[ ! -s "$ROOT/browser.log" ] && printf "%s\n" "$out" | grep -q "enter BCDF-GHJK"' "$out"
curl -fsS -X POST "$GITSTALK_WEB/__mode?deny=1" >/dev/null
out=$(sh "$SETUP" register --key "$HOME/.ssh/id_ed25519.pub" 2>&1)
status=$?
check 'a declined request fails and says nothing was added' \
  '[ $status -ne 0 ] && printf "%s\n" "$out" | grep -q "declined"' "$out"
check 'a private key is refused before anything is sent' \
  '! sh "$SETUP" register --key "$HOME/.ssh/id_ed25519" >/dev/null 2>&1'

# --- once the SSH endpoint is live ---------------------------------------------------------
curl -fsS -X POST "$GITSTALK_WEB/__mode?ssh=ssh.gitstalk.test" >/dev/null
out=$(sh "$SETUP" register --agent-key "$(fingerprint "$ROOT/op_key.pub")" --agent "$OP_SOCK" --no-browser 2>&1)
state=$(curl -fsS "$GITSTALK_WEB/__state")
check 'with SSH live, register asks for no HTTPS token' \
  'printf "%s\n" "$out" | grep -q "^approved" && printf "%s" "$state" | sed "s/,\"creates\":.*//" | tr "}" "\n" | tail -n 2 | grep -q "\"https_token\":false"' "$out"
mkdir -p "$ROOT/sshrepo" && git -C "$ROOT/sshrepo" init -q
out=$(cd "$ROOT/sshrepo" && sh "$SETUP" remote smoke/demo 2>&1)
check 'with SSH live, remote uses ssh:// and points ssh at the chosen agent key for that host only' \
  '[ "$(git -C "$ROOT/sshrepo" remote get-url origin)" = "ssh://git@ssh.gitstalk.test/smoke/demo.git" ] && grep -q "^Host ssh.gitstalk.test" "$HOME/.ssh/config" && grep -q "IdentityAgent \"$OP_SOCK\"" "$HOME/.ssh/config"' "$out"
curl -fsS -X POST "$GITSTALK_WEB/__mode" >/dev/null

# --- the "Env vars" block (CI): no helper, no prompt -------------------------------------------
env_ls_remote() {
  env -i PATH="$PATH" HOME="$ROOT/ci" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$ROOT/ci/.gitconfig" \
    GITSTALK_TOKEN="$1" GIT_TERMINAL_PROMPT=0 GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0="$2" GIT_CONFIG_VALUE_0="$3" git ls-remote "$ORIGIN/smoke/demo.git" 2>&1
}
mkdir -p "$ROOT/ci" && : >"$ROOT/ci/.gitconfig"
HELPER='!f() { echo "username=x"; echo "password=$GITSTALK_TOKEN"; }; f'
out=$(env_ls_remote bsd_fake_deploy "credential.$ORIGIN.helper" "$HELPER")
check 'env vars: the credential-helper variant reads GITSTALK_TOKEN' 'printf "%s\n" "$out" | grep -q "refs/heads/main"' "$out"
out=$(env_ls_remote bsd_fake_deploy "http.$ORIGIN/.extraheader" 'Authorization: Bearer bsd_fake_deploy')
check 'env vars: the extraheader Bearer variant works' 'printf "%s\n" "$out" | grep -q "refs/heads/main"' "$out"
out=$(env_ls_remote '' "core.askPass" '')
check 'without a credential git fails at once and prints the hint as remote: lines' \
  'printf "%s\n" "$out" | grep -q "terminal prompts disabled\|remote: Gitstalk"' "$out"

printf '\n%s passed, %s failed (git %s, %s)\n' "$PASSED" "$FAILED" "$(git --version | cut -d" " -f3)" "$(uname -s)"
[ "$FAILED" -eq 0 ]
