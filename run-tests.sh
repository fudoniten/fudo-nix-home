#!/usr/bin/env bash
# Local test runner - mirrors CI checks
# Run this before pushing to catch issues early

set -e  # Exit on first error

echo "=========================================="
echo "Running fudo-nix-home test suite"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED_TESTS=()

run_test() {
    local test_name=$1
    shift
    echo -e "${YELLOW}▶${NC} Running: $test_name"
    if "$@"; then
        echo -e "${GREEN}✓${NC} $test_name passed"
        echo ""
        return 0
    else
        echo -e "${RED}✗${NC} $test_name failed"
        echo ""
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Test 1: Flake check
run_test "Flake structure validation" \
    nix flake check --show-trace || true

# Test 2: Static analysis
run_test "Static analysis (statix)" \
    nix run nixpkgs#statix -- check . || true

# Test 3: Dead code detection. Unused function arguments are allowed: the
# curried user-file convention passes every file the same arguments.
run_test "Dead code detection (deadnix)" \
    nix run nixpkgs#deadnix -- --fail --no-lambda-arg --no-lambda-pattern-names . || true

# Test 4: Format checking
run_test "Format check (nixfmt-classic; 'nix fmt' to fix)" \
    nix fmt -- --check . || true

# Test 5: Module validation
run_test "NixOS module structure (default)" \
    nix eval .#nixosModules.default --show-trace || true

run_test "NixOS module structure (home-configuration)" \
    nix eval .#nixosModules.home-configuration --show-trace || true

run_test "mkModule.niten function exists" \
    nix eval .#mkModule.niten --apply 'x: builtins.isFunction x' --show-trace || true

# Test 6: Flake outputs
run_test "Flake outputs validation" \
    nix flake show --show-trace || true

# Test 7: Evaluate every user config through both consumption paths,
# including standalone on aarch64-darwin (evaluation only, no builds)
run_test "User configurations evaluate" \
    nix eval --impure --json --expr \
    'import ./tests/eval.nix { flake = builtins.getFlake (toString ./.); }' || true

# Test 8: User configuration syntax check
# Just verify the Nix files are syntactically valid
echo -e "${YELLOW}▶${NC} Running: User configuration syntax checks"
USERS=(hermes jasper ken niten openclaw reaper root xiaoxuan)
for user in "${USERS[@]}"; do
    if nix-instantiate --parse "users/${user}.nix" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} users/${user}.nix syntax is valid"
    else
        echo -e "${RED}✗${NC} users/${user}.nix has syntax errors"
        FAILED_TESTS+=("Syntax check: users/${user}.nix")
    fi
done
echo ""

# Test 9: Custom modules syntax check
echo -e "${YELLOW}▶${NC} Running: Custom modules syntax checks"
for module in modules/programs/*.nix modules/services/*.nix modules/default.nix; do
    if [ -f "$module" ]; then
        if nix-instantiate --parse "$module" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $module syntax is valid"
        else
            echo -e "${RED}✗${NC} $module has syntax errors"
            FAILED_TESTS+=("Syntax check: $module")
        fi
    fi
done
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Your changes are ready to push."
    exit 0
else
    echo -e "${RED}✗ ${#FAILED_TESTS[@]} test(s) failed:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}•${NC} $test"
    done
    echo ""
    echo "Please fix the failing tests before pushing."
    exit 1
fi
