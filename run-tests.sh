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
echo -e "${YELLOW}▶${NC} Running: Static analysis (statix)"
if nix run nixpkgs#statix -- check .; then
    echo -e "${GREEN}✓${NC} Static analysis passed (no issues found)"
else
    echo -e "${YELLOW}⚠${NC} Static analysis found suggestions (not blocking)"
fi
echo ""

# Test 3: Dead code detection
echo -e "${YELLOW}▶${NC} Running: Dead code detection (deadnix)"
if nix run nixpkgs#deadnix -- --fail .; then
    echo -e "${GREEN}✓${NC} No dead code found"
else
    echo -e "${YELLOW}⚠${NC} Dead code detected (not blocking)"
fi
echo ""

# Test 4: Format checking
echo -e "${YELLOW}▶${NC} Running: Format check (nixpkgs-fmt)"
if nix run nixpkgs#nixpkgs-fmt -- --check .; then
    echo -e "${GREEN}✓${NC} Code formatting is correct"
else
    echo -e "${YELLOW}⚠${NC} Formatting issues found (run 'nix run nixpkgs#nixpkgs-fmt .' to fix)"
fi
echo ""

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

# Test 7: User configuration syntax check
# Just verify the Nix files are syntactically valid
echo -e "${YELLOW}▶${NC} Running: User configuration syntax checks"
USERS=(niten ken jasper xiaoxuan root reaper)
for user in "${USERS[@]}"; do
    if nix-instantiate --parse "users/${user}.nix" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} users/${user}.nix syntax is valid"
    else
        echo -e "${RED}✗${NC} users/${user}.nix has syntax errors"
        FAILED_TESTS+=("Syntax check: users/${user}.nix")
    fi
done
echo ""

# Test 8: Custom modules syntax check
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
