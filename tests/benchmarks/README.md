# Cbox performance smoke measurements

CI measures the exact Trixie image built by the framework integration job. It
reuses the local image instead of compiling and downloading the same chain on
another runner. Nothing is published by this benchmark.

```bash
BENCHMARK_IMAGE=cbox-trixie bash tests/benchmarks/run-benchmarks.sh
# On OrbStack, set DOCKER_CONTEXT=orbstack if it is not your default context.
```

Requires Docker and Python 3. The image must already exist locally. Override
`BENCHMARK_RESULTS_DIR` to change the default `tests/benchmarks/results` directory.

The JSON report records the immutable image ID, image size, PHP version, three
CLI hash-workload timings, three startup timings and 50 serial HTTP timings.
Startup ends only when an actual PHP fixture returns the expected JSON, under
512 MiB and one CPU. Readiness has a 60-second deadline. Failed requests,
missing images and incorrect PHP results fail the job; they never become zero
or N/A measurements. Each test container is removed after use.

These are smoke measurements on a shared runner, not production capacity,
concurrent throughput, OPcache effectiveness or a cross-distribution comparison.
No performance thresholds are enforced. The old Alpine/Debian/Ubuntu comparison
is removed because it did not target the Trixie image CI actually built.
