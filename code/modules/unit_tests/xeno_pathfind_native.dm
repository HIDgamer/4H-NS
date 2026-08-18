/**
 * Verifies the native xeno pathfinding functions (tools/rust/rust-g/src/
 * xeno_pathfind.rs, part of rust-g itself), if present on this host, are
 * actually callable through BYOND's call_ext() and return correct results -
 * the Rust side has its own `cargo test` suite covering the A* logic itself,
 * this only checks the FFI plumbing.
 *
 * Deliberately does NOT fail if the functions are simply absent - an older
 * rust-g build predating the xeno_pathfind feature is an expected,
 * non-broken state (the AI falls back to step_towards()), not a regression.
 */
/datum/unit_test/xeno_pathfind_native/Run()
	var/result = rust_xeno_pathfind("5,5,0,0,4,0", "0000000000000000000000000")

	if(!__xeno_pathfind_available)
		Warn("Native xeno_pathfind functions not found/loadable on this host's rust-g build - AI xeno movement will fall back to the greedy step_towards() behavior instead of real pathfinding. Rebuild librust_g.so from tools/rust/rust-g (feature \"xeno_pathfind\") for this platform to enable it.")
		return

	TEST_ASSERT(result == "0,0;1,0;2,0;3,0;4,0", "Native pathfinder returned an unexpected result for a trivial open 5-tile straight line: got \"[result]\"")
