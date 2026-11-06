#!/bin/bash
# Test Mac chia nhóm (xem test-ios.sh): build CutCutMacSpike + CutCutMacTests, quá ~45 phút in CHƯA XONG để gõ lại chạy tiếp.
MODE=mac exec bash "$(dirname "$0")/test-ios.sh" "$@"
