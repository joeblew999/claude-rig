#!/usr/bin/env nu
# capture.nu — tests for tasks/capture.nu.
#
# capture is what stands between the owner's Mac and a public repo, so these
# check that a secret or a personal path stops it, and that what it lets
# through is cleaned. Everything happens in a temp folder.
#
#   nu tests/capture.nu

const CAPTURE = path self ../tasks/capture.nu

# Run capture from a made-up Claude folder into a made-up destination.
def capture [home: path, dest: path]: nothing -> record {
  with-env { CLAUDE_HOME: $home, RIG_CAPTURE_DEST: $dest } {
    ^$nu.current-exe $CAPTURE | complete
  }
}

def check [what: string, passed: bool] {
  if not $passed { error make { msg: $"FAILED: ($what)" } }
  print $"    ok  ($what)"
}

# A Claude folder like the owner's: settings with Mac-only keys and a secret
# in the environment, one skill, and the account's synced skills.
def make-home [root: path, name: string]: nothing -> path {
  let home = $root | path join $name
  mkdir ($home | path join skills good) ($home | path join skills synced account)
  "# A skill\n" | save ($home | path join skills good SKILL.md)
  "synced" | save ($home | path join skills synced account SKILL.md)
  "x" | save ($home | path join skills good .DS_Store)
  {
    model: "opus"
    env: {API_TOKEN: "hunter2", EDITOR: "vim"}
    permissions: {defaultMode: "default", additionalDirectories: ["/somewhere/local"]}
    sandbox: {network: {allowUnixSockets: ["/somewhere/docker.sock"], allowLocalBinding: true}}
  } | to json | save ($home | path join settings.json)
  $home
}

def test-clean-capture [root: path] {
  print "a config with nothing secret in the files"
  let home = make-home $root clean
  let dest = $root | path join clean-out
  let run = capture $home $dest
  check "the capture succeeds" ($run.exit_code == 0)
  let settings = open --raw ($dest | path join settings.json) | from json
  check "an environment entry named like a secret is dropped" ("API_TOKEN" not-in $settings.env)
  check "other environment entries are kept" ($settings.env.EDITOR == "vim")
  check "the Mac's extra folders are dropped" ("additionalDirectories" not-in $settings.permissions)
  check "the Mac's socket paths are dropped" ("allowUnixSockets" not-in $settings.sandbox.network)
  check "settings next to a dropped key are kept" ($settings.sandbox.network.allowLocalBinding == true and $settings.permissions.defaultMode == "default")
  check "the skill is captured" ($dest | path join skills good SKILL.md | path exists)
  check "the account's synced skills are not" (not ($dest | path join skills synced | path exists))
  check ".DS_Store files are not" (not ($dest | path join skills good .DS_Store | path exists))
}

def test-stops [root: path, name: string, text: string, problem: string] {
  let home = make-home $root $name
  let dest = $root | path join $"($name)-out"
  mkdir $dest
  "what was captured before" | save ($dest | path join marker)
  $text | save --force ($home | path join skills good SKILL.md)
  let run = capture $home $dest
  check "the capture stops with an error" ($run.exit_code != 0)
  check "the error says why" ($run.stderr =~ $problem)
  check "the error names the file" ($run.stderr =~ "SKILL.md")
  check "what was captured before is untouched" ((names $dest) == ["marker"])
}

def names [dir: path]: nothing -> list<string> {
  ls --all $dir | get name | each {|path| $path | path basename } | sort
}

def main [] {
  let root = mktemp --directory | path expand
  try {
    test-clean-capture $root
    print "a skill with a GitHub token in it"
    test-stops $root github $"token: ghp_('a' | fill --width 36 --character 'a')" "possible secret"
    print "a skill with an Anthropic key in it"
    test-stops $root anthropic $"key: sk-ant-('b' | fill --width 24 --character 'b')" "possible secret"
    print "a skill with a private key in it"
    test-stops $root private-key "-----BEGIN OPENSSH PRIVATE KEY-----" "possible secret"
    print "a skill that mentions a folder under this machine's home"
    test-stops $root home-path $"see ($nu.home-dir | path join projects thing)" "a path under"
  } catch {|failure|
    rm --recursive --force $root
    print --stderr $failure.msg
    exit 1
  }
  rm --recursive --force $root
  print "capture: every test passed."
}
