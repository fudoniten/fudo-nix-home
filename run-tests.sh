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

# Test 5: Evaluate all user configurations
USERS=(niten ken jasper xiaoxuan root reaper)
for user in "${USERS[@]}"; do
    run_test "Evaluate configuration: $user" \
        nix eval .#homeConfigurations.$user.config.home.username --show-trace || true
done

# Test 6: Build activation packages (dry-run)
for user in "${USERS[@]}"; do
    run_test "Build activation package: $user (dry-run)" \
        nix build .#homeConfigurations.$user.activationPackage --dry-run --show-trace || true
done

# Test 7: Module validation
run_test "NixOS module structure validation" \
    nix eval .#nixosModules.fudo-home --apply 'x: x ? config' --show-trace || true

run_test "Flake outputs validation" \
    nix flake show --show-trace || true

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
