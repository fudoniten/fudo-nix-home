# TODO

This document tracks unimplemented but recommended future work for the fudo-nix-home repository.

## Locket Improvements

### Phase 2: Proper Nix Package

Convert locket from bash scripts with nix-shell shebangs to a proper Nix package.

**Current State:**
- Scripts use `#!/usr/bin/env nix-shell` with explicit dependencies
- Works well but has ~1-2 second startup time on first run
- Each script independently fetches dependencies

**Proposed Enhancement:**
Create `pkgs/locket/default.nix` that:
- Packages all locket scripts together
- Properly declares dependencies
- Can be installed via `home.packages = [ pkgs.locket ];`
- Provides faster startup times
- Enables easier distribution

**Benefits:**
- Faster startup (no nix-shell overhead)
- Single package to install
- Better integration with NixOS/Home Manager
- Can be published to nixpkgs if desired

**Implementation Notes:**
```nix
# Example structure
pkgs.locket = pkgs.stdenv.mkDerivation {
  name = "locket";
  src = ./bin;
  buildInputs = [ age jq bash coreutils findutils gnugrep gnused openssh ];
  installPhase = ''
    mkdir -p $out/bin
    cp locket* $out/bin/
    # Patch shebangs and wrap with proper PATH
  '';
};
```

### Phase 3: System-Wide Remote Operations

Add `locket-remote` commands that can modify secrets directly from GitHub.

**Current State:**
- Locket scripts work on locally cloned repositories
- Requires manual clone, modify, commit, push workflow
- No way to modify secrets from systems without the full repo

**Proposed Enhancement:**
Create system-wide scripts that:
1. Clone the fudo-nix-home repo to `/tmp`
2. Make secret modifications (add, edit, remove)
3. Create a branch and push changes
4. Create a PR via GitHub CLI for review
5. Clean up temporary clone

**Configuration:**
```nix
# In user profiles (niten.nix, jasper.nix, etc.)
programs.locket-remote = {
  enable = true;
  repository = "git@github.com:fudoniten/fudo-nix-home.git";
  # or: repository = builtins.getEnv "LOCKET_REPO";
};
```

**Commands to Add:**
- `locket-remote add <user> <name> [options]` - Add secret via GitHub
- `locket-remote edit <user> <name>` - Edit secret via GitHub
- `locket-remote remove <user> <name>` - Remove secret via GitHub
- `locket-remote sync` - Pull latest secrets to local system

**Benefits:**
- Modify secrets from any system
- Don't need full repo clone
- Automatic PR creation for safety
- Reviewable changes before merge

**Security Considerations:**
- Requires GitHub authentication (SSH keys or `gh` CLI)
- Profile private keys still needed for decryption/editing
- PR-based workflow maintains audit trail
- Could support optional direct push for trusted systems

**Implementation Architecture:**
```
┌─────────────────────────────────────────────────────┐
│ User runs: locket-remote add niten my-secret        │
│   → Clone repo to /tmp/locket-XXXXX/                │
│   → Run local locket add with modifications          │
│   → Create feature branch                            │
│   → Push branch to GitHub                            │
│   → Create PR via gh CLI                             │
│   → Clean up /tmp/locket-XXXXX/                      │
└─────────────────────────────────────────────────────┘
```

**Authentication Options:**
1. **SSH Keys** (most secure, requires setup per host)
2. **GitHub CLI** (`gh auth login` - cached credentials)
3. **Environment Variables** (`GITHUB_TOKEN` - for automation)

**Workflow Modes:**
- `--pr` (default): Create PR for review
- `--direct`: Push directly to default branch (trusted systems only)
- `--draft`: Create draft PR

**Example Usage:**
```bash
# Add a secret from any system
locket-remote add niten api-key \
  --target ".config/myapp/key" \
  --profiles default \
  --file /path/to/key

# Edit existing secret
locket-remote edit niten ssh-github

# Remove secret
locket-remote remove niten old-token --force

# Sync latest secrets to current system
locket-remote sync
```

**Related Configuration:**
User profiles should set repository location:
```nix
# In niten.nix, jasper.nix, etc.
home.sessionVariables = {
  LOCKET_REPO = "git@github.com:fudoniten/fudo-nix-home.git";
  # or alternative: LOCKET_REPO_URL for HTTPS
};
```

## Other Future Work

### Home Manager Module Improvements

*Add other unimplemented improvements here as they are identified.*

### Build System Optimizations

*Add build-related TODOs here.*

### Documentation

- [ ] Add video tutorial for locket setup
- [ ] Create migration guide from agenix/sops-nix
- [ ] Document disaster recovery procedures
