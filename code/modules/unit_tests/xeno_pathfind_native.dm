/**
 * Verifies the native xeno_pathfind extension (tools/rust/xeno_pathfind/),
 * if present on this host, is actually callable through BYOND's call_ext()
 * and returns correct results - the Rust side has its own `cargo test` suite
 * covering the A* logic itself, this only checks the FFI plumbing.
 *
 * Deliberately does NOT fail if the library is simply absent - only a
 * Windows .dll has been built and committed so far (see
 * tools/rust/xeno_pathfind/README expectations); a Linux host needs
 * libxeno_pathfind.so built there before this activates, which is an
 * expected, non-broken state, not a regression.
 */
/datum/unit_test/xeno_pathfind_native/Run()
	var/result = rustg_xeno_pathfind("5,5,0,0,4,0", "0000000000000000000000000")

	if(!__xeno_pathfind_available)
		Warn("Native xeno_pathfind library not found/loadable on this host - AI xeno movement will fall back to the greedy step_towards() behavior instead of real pathfinding. Build tools/rust/xeno_pathfind for this platform to enable it.")
		return

	TEST_ASSERT(result == "0,0;1,0;2,0;3,0;4,0", "Native pathfinder returned an unexpected result for a trivial open 5-tile straight line: got \"[result]\"")
