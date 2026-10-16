#!/bin/bash
# Comprehensive test script for Project Bebop
set -e

echo "==================================="
echo "Project Bebop - Test Suite"
echo "==================================="
echo ""

echo "[1/3] Running unit tests..."
godot --headless res://tests/run_tests_simple.gd
echo ""

echo "[2/3] Verifying scene loads without errors..."
timeout 5 godot --headless --quit-after 100 res://scenes/combat/combat_scene.tscn
if [ $? -eq 0 ]; then
    echo "✓ Combat scene loads successfully"
else
    echo "✗ Combat scene failed to load"
    exit 1
fi
echo ""

echo "[3/3] Running playability verification..."
godot --headless res://tests/verify_e1_playable.gd
echo ""

echo "==================================="
echo "All tests passed!"
echo "==================================="
