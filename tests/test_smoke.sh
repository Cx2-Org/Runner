test_lib_sources() { if source scripts/lib.sh 2>/dev/null; then assert_eq ok ok smoke; else assert_eq ok missing smoke; fi; }
