#!/usr/bin/env bash
# CI Check Script for Ralph Loop
# Customize this for your project's CI commands

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Timeout for test suite (2 minutes)
TEST_TIMEOUT=120

# Use gtimeout on macOS (coreutils), timeout on Linux
if command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
else
    echo -e "${YELLOW}Warning: timeout command not found. Tests will run without timeout.${NC}"
    TIMEOUT_CMD=""
fi

FAILED=0

echo "========================================"
echo "Running CI Checks"
echo "========================================"

# TODO: Customize these commands for your project
# Examples:
#   npm run typecheck
#   npm run lint
#   npm test
#   cargo check && cargo test
#   go build ./... && go test ./...

echo -e "\n${YELLOW}[1/2] Running quality checks...${NC}"
# if npm run check; then
#     echo -e "${GREEN}Quality checks passed!${NC}"
# else
#     echo -e "${RED}Quality checks failed!${NC}"
#     FAILED=1
# fi
echo -e "${YELLOW}TODO: Add your quality check commands${NC}"

echo -e "\n${YELLOW}[2/2] Running tests (timeout: ${TEST_TIMEOUT}s)...${NC}"
# Wrap test commands with timeout if available
# if [ -n "$TIMEOUT_CMD" ]; then
#     if $TIMEOUT_CMD "$TEST_TIMEOUT" npm test; then
#         echo -e "${GREEN}Tests passed!${NC}"
#     else
#         echo -e "${RED}Tests failed or timed out!${NC}"
#         FAILED=1
#     fi
# else
#     if npm test; then
#         echo -e "${GREEN}Tests passed!${NC}"
#     else
#         echo -e "${RED}Tests failed!${NC}"
#         FAILED=1
#     fi
# fi
echo -e "${YELLOW}TODO: Add your test commands${NC}"

echo ""
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All CI checks passed!${NC}"
    exit 0
else
    echo -e "${RED}CI checks failed!${NC}"
    exit 1
fi
