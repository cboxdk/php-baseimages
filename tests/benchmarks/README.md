# PHPeek Performance Benchmarks

Comprehensive performance benchmarking suite for comparing PHPeek base images across Alpine, Debian, and Ubuntu variants.

## Benchmark Suite

### 1. Image Size Comparison
Measures and compares:
- Uncompressed image size
- Compressed image size (gzipped)
- Storage efficiency across OS variants

### 2. Container Startup Time
Measures:
- Time to container ready (average of 5 runs)
- Standard deviation for consistency
- Health check response time

### 3. PHP Performance
Tests:
- Operations per second (array operations benchmark)
- Memory usage patterns
- OPcache effectiveness
- JIT compiler impact

### 4. HTTP Request Performance
Benchmarks:
- Requests per second (RPS)
- Average latency
- P95 latency (if Apache Bench available)
- Nginx + PHP-FPM throughput

## Running Benchmarks

### Prerequisites
```bash
# Required tools
- Docker
- bc (basic calculator)
- jq (JSON processor)

# Optional (for better HTTP benchmarks)
- Apache Bench (ab)
```

### Build Images First
```bash
# Build all three variants
docker build -t phpeek-alpine -f php-fpm-nginx/8.3/alpine/Dockerfile .
docker build -t phpeek-debian -f php-fpm-nginx/8.3/debian/Dockerfile .
docker build -t phpeek-ubuntu -f php-fpm-nginx/8.3/ubuntu/Dockerfile .
```

### Run All Benchmarks
```bash
./tests/benchmarks/run-benchmarks.sh
```

### Run Individual Benchmarks
Edit `run-benchmarks.sh` and comment out unwanted benchmarks in the `main()` function.

## Benchmark Results

Results are saved to `tests/benchmarks/results/` with timestamps:

```
tests/benchmarks/results/
├── image-size-20241120_143022.md
├── startup-time-20241120_143022.md
├── php-performance-20241120_143022.md
├── http-performance-20241120_143022.md
└── summary-20241120_143022.md
```

### Example Summary Output

```markdown
# PHPeek Performance Benchmark Summary

## Image Size Comparison

| OS Variant | Image Size | Compressed Size |
|------------|------------|-----------------|
| alpine     | 52.3 MB    | 21.4 MB        |
| debian     | 123.5 MB   | 45.2 MB        |
| ubuntu     | 131.2 MB   | 47.8 MB        |

## Container Startup Time Comparison

| OS Variant | Startup Time (avg of 5 runs) | Std Dev |
|------------|-------------------------------|---------|
| alpine     | 1.234s                        | 0.045s  |
| debian     | 1.456s                        | 0.062s  |
| ubuntu     | 1.523s                        | 0.071s  |

## PHP Performance Comparison

| OS Variant | Operations/sec | Memory Usage | OPcache Hits |
|------------|---------------|--------------|--------------|
| alpine     | 45,234        | 12.5MB       | 98.5%        |
| debian     | 44,892        | 13.2MB       | 98.3%        |
| ubuntu     | 44,756        | 13.4MB       | 98.1%        |

## HTTP Request Performance Comparison

| OS Variant | Requests/sec | Latency (avg) | Latency (p95) |
|------------|--------------|---------------|---------------|
| alpine     | 2,345        | 4.26ms        | 6.82ms        |
| debian     | 2,312        | 4.33ms        | 6.95ms        |
| ubuntu     | 2,289        | 4.37ms        | 7.01ms        |
```

## CI/CD Integration

Benchmarks run automatically in GitHub Actions on:
- Every push to main/develop
- Every pull request
- Manual workflow dispatch

### View Results in GitHub Actions
1. Go to Actions tab
2. Select "Integration Tests" workflow
3. Click on latest run
4. Download "benchmark-results" artifact

### Benchmark Artifacts
GitHub Actions uploads results as artifacts:
- Available for 90 days
- Downloadable as ZIP
- Contains all markdown reports

## Interpreting Results

### Image Size
- **Alpine**: ~50MB - Best for size-constrained environments
- **Debian**: ~120MB - Balance of size and compatibility
- **Ubuntu**: ~130MB - Most compatible, slightly larger

**Recommendation**: Choose Alpine for microservices, Debian/Ubuntu for traditional apps.

### Startup Time
- Differences typically 10-30% between variants
- Alpine usually fastest due to smaller size
- Consider warmup time in production (not just cold start)

**Recommendation**: Startup time differences minimal in production with warm containers.

### PHP Performance
- Performance similar across variants (~2-5% difference)
- glibc (Debian/Ubuntu) may have slight edge in some workloads
- musl (Alpine) optimized for size, not always speed

**Recommendation**: PHP performance differences negligible for most applications.

### HTTP Performance
- Nginx performance consistent across variants
- Network overhead typically dominates request latency
- Application code has more impact than base OS

**Recommendation**: Base OS choice has minimal impact on HTTP performance.

## Benchmark Limitations

### What These Benchmarks Don't Measure
- Real application performance (use your own benchmarks!)
- Database query performance
- External API call latency
- Complex business logic performance
- Production load patterns

### Factors Not Included
- Multi-core scaling
- High concurrency scenarios (>1000 concurrent)
- Long-running request behavior
- Memory pressure under load
- Network topology impact

### Recommendations for Production
1. **Run your own benchmarks** with your actual application
2. **Test under realistic load** matching your traffic patterns
3. **Measure end-to-end** including databases, caches, APIs
4. **Monitor in production** with APM tools (New Relic, DataDog, etc.)
5. **Consider total cost** (size, performance, maintenance)

## Adding Custom Benchmarks

### Create New Benchmark Function
Edit `run-benchmarks.sh` and add:

```bash
benchmark_your_test() {
    info "Running your custom benchmark..."

    echo "# Your Benchmark Results" > "$RESULTS_DIR/your-test-$TIMESTAMP.md"
    echo "" >> "$RESULTS_DIR/your-test-$TIMESTAMP.md"

    for variant in alpine debian ubuntu; do
        IMAGE="phpeek-${variant}"

        # Your test logic here
        RESULT="your_measurement"

        echo "| $variant | $RESULT |" >> "$RESULTS_DIR/your-test-$TIMESTAMP.md"
    done

    success "Your benchmark complete"
}
```

Then call it from `main()`:
```bash
main() {
    # ... existing benchmarks ...
    benchmark_your_test
    generate_summary
}
```

## Troubleshooting

### Docker Not Found
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### bc Not Found
```bash
# Ubuntu/Debian
apt-get install bc

# macOS
brew install bc
```

### jq Not Found
```bash
# Ubuntu/Debian
apt-get install jq

# macOS
brew install jq
```

### Apache Bench Not Available
```bash
# Ubuntu/Debian
apt-get install apache2-utils

# macOS
# Already included with macOS
```

### Images Not Found
Make sure to build images first:
```bash
docker build -t phpeek-alpine -f php-fpm-nginx/8.3/alpine/Dockerfile .
docker build -t phpeek-debian -f php-fpm-nginx/8.3/debian/Dockerfile .
docker build -t phpeek-ubuntu -f php-fpm-nginx/8.3/ubuntu/Dockerfile .
```

## Related Documentation

- [Performance Tuning Guide](../../docs/advanced/performance-tuning.md) - Optimize production performance
- [Choosing a Variant](../../docs/getting-started/choosing-variant.md) - OS selection guide
- [Production Deployment](../../docs/guides/production-deployment.md) - Production best practices

## Future Enhancements

Potential benchmark additions:

- [ ] Memory pressure testing (OOM scenarios)
- [ ] CPU throttling impact
- [ ] Disk I/O performance
- [ ] Network throughput testing
- [ ] SSL/TLS termination performance
- [ ] WebSocket connection benchmarks
- [ ] GraphQL query performance
- [ ] File upload/download performance
- [ ] Session storage benchmarks (file vs Redis)
- [ ] Cron job execution timing
- [ ] Queue worker performance
- [ ] Comparison with competitor images (ServerSideUp, Bitnami)
