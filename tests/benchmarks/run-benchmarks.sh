#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RESULTS_DIR="tests/benchmarks/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Ensure results directory exists
mkdir -p "$RESULTS_DIR"

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Benchmark: Image size comparison
benchmark_image_size() {
    info "Benchmarking image sizes..."

    echo "# Image Size Comparison" > "$RESULTS_DIR/image-size-$TIMESTAMP.md"
    echo "" >> "$RESULTS_DIR/image-size-$TIMESTAMP.md"
    echo "| OS Variant | Image Size | Compressed Size |" >> "$RESULTS_DIR/image-size-$TIMESTAMP.md"
    echo "|------------|------------|-----------------|" >> "$RESULTS_DIR/image-size-$TIMESTAMP.md"

    for variant in alpine debian ubuntu; do
        IMAGE="cbox-${variant}"
        SIZE=$(docker images --format "{{.Size}}" "$IMAGE" 2>/dev/null || echo "N/A")

        # Get compressed size by saving to tar and checking size
        COMPRESSED="N/A"
        if docker images "$IMAGE" &>/dev/null; then
            docker save "$IMAGE" 2>/dev/null | gzip | wc -c | awk '{printf "%.1f MB", $1/1024/1024}' > /tmp/compressed-size.txt
            COMPRESSED=$(cat /tmp/compressed-size.txt)
            rm -f /tmp/compressed-size.txt
        fi

        echo "| $variant | $SIZE | $COMPRESSED |" >> "$RESULTS_DIR/image-size-$TIMESTAMP.md"
    done

    echo "" >> "$RESULTS_DIR/image-size-$TIMESTAMP.md"
    success "Image size benchmark complete"
}

# Benchmark: Container startup time
benchmark_startup_time() {
    info "Benchmarking container startup times..."

    echo "# Container Startup Time Comparison" > "$RESULTS_DIR/startup-time-$TIMESTAMP.md"
    echo "" >> "$RESULTS_DIR/startup-time-$TIMESTAMP.md"
    echo "| OS Variant | Startup Time (avg of 5 runs) | Std Dev |" >> "$RESULTS_DIR/startup-time-$TIMESTAMP.md"
    echo "|------------|-------------------------------|---------|" >> "$RESULTS_DIR/startup-time-$TIMESTAMP.md"

    for variant in alpine debian ubuntu; do
        IMAGE="cbox-${variant}"
        TIMES=()

        info "Testing $variant startup time (5 runs)..."

        for i in {1..5}; do
            START=$(date +%s.%N)
            CONTAINER_ID=$(docker run -d "$IMAGE" 2>/dev/null || echo "")

            if [ -n "$CONTAINER_ID" ]; then
                # Wait for health check or service ready
                docker exec "$CONTAINER_ID" sh -c 'until curl -sf http://localhost/health > /dev/null 2>&1; do sleep 0.1; done' 2>/dev/null || true
                END=$(date +%s.%N)

                TIME=$(echo "$END - $START" | bc)
                TIMES+=("$TIME")

                docker rm -f "$CONTAINER_ID" > /dev/null 2>&1
            else
                TIMES+=("N/A")
            fi

            sleep 1
        done

        # Calculate average and std dev
        if [ ${#TIMES[@]} -gt 0 ]; then
            AVG=$(printf '%s\n' "${TIMES[@]}" | awk '{sum+=$1} END {printf "%.3fs", sum/NR}')
            STDDEV=$(printf '%s\n' "${TIMES[@]}" | awk '{sum+=$1; sumsq+=$1*$1} END {printf "%.3fs", sqrt(sumsq/NR - (sum/NR)^2)}')
            echo "| $variant | $AVG | $STDDEV |" >> "$RESULTS_DIR/startup-time-$TIMESTAMP.md"
        else
            echo "| $variant | N/A | N/A |" >> "$RESULTS_DIR/startup-time-$TIMESTAMP.md"
        fi
    done

    echo "" >> "$RESULTS_DIR/startup-time-$TIMESTAMP.md"
    success "Startup time benchmark complete"
}

# Benchmark: PHP performance (opcache)
benchmark_php_performance() {
    info "Benchmarking PHP performance..."

    echo "# PHP Performance Comparison" > "$RESULTS_DIR/php-performance-$TIMESTAMP.md"
    echo "" >> "$RESULTS_DIR/php-performance-$TIMESTAMP.md"
    echo "| OS Variant | Operations/sec | Memory Usage | OPcache Hits |" >> "$RESULTS_DIR/php-performance-$TIMESTAMP.md"
    echo "|------------|---------------|--------------|--------------|" >> "$RESULTS_DIR/php-performance-$TIMESTAMP.md"

    # Create test PHP script
    cat > /tmp/bench.php << 'EOF'
<?php
$start = microtime(true);
$iterations = 100000;

for ($i = 0; $i < $iterations; $i++) {
    $array = range(1, 100);
    array_map(function($n) { return $n * 2; }, $array);
    array_filter($array, function($n) { return $n % 2 === 0; });
}

$end = microtime(true);
$time = $end - $start;
$ops = round($iterations / $time, 2);

echo json_encode([
    'ops_per_sec' => $ops,
    'memory_mb' => round(memory_get_peak_usage(true) / 1024 / 1024, 2),
    'time_sec' => round($time, 3)
]);
EOF

    for variant in alpine debian ubuntu; do
        IMAGE="cbox-${variant}"

        CONTAINER_ID=$(docker run -d -v /tmp/bench.php:/tmp/bench.php "$IMAGE" tail -f /dev/null 2>/dev/null || echo "")

        if [ -n "$CONTAINER_ID" ]; then
            # Run benchmark
            RESULT=$(docker exec "$CONTAINER_ID" php /tmp/bench.php 2>/dev/null || echo '{"ops_per_sec":"N/A","memory_mb":"N/A"}')

            OPS=$(echo "$RESULT" | jq -r '.ops_per_sec // "N/A"')
            MEM=$(echo "$RESULT" | jq -r '.memory_mb // "N/A"')

            # Check OPcache stats
            OPCACHE=$(docker exec "$CONTAINER_ID" php -r 'echo json_encode(opcache_get_status(false));' 2>/dev/null || echo '{}')
            HITS=$(echo "$OPCACHE" | jq -r '.opcache_statistics.hits // "N/A"')

            echo "| $variant | $OPS | ${MEM}MB | $HITS |" >> "$RESULTS_DIR/php-performance-$TIMESTAMP.md"

            docker rm -f "$CONTAINER_ID" > /dev/null 2>&1
        else
            echo "| $variant | N/A | N/A | N/A |" >> "$RESULTS_DIR/php-performance-$TIMESTAMP.md"
        fi
    done

    rm -f /tmp/bench.php
    echo "" >> "$RESULTS_DIR/php-performance-$TIMESTAMP.md"
    success "PHP performance benchmark complete"
}

# Benchmark: HTTP request performance
benchmark_http_performance() {
    info "Benchmarking HTTP request performance..."

    echo "# HTTP Request Performance Comparison" > "$RESULTS_DIR/http-performance-$TIMESTAMP.md"
    echo "" >> "$RESULTS_DIR/http-performance-$TIMESTAMP.md"
    echo "| OS Variant | Requests/sec | Latency (avg) | Latency (p95) |" >> "$RESULTS_DIR/http-performance-$TIMESTAMP.md"
    echo "|------------|--------------|---------------|---------------|" >> "$RESULTS_DIR/http-performance-$TIMESTAMP.md"

    # Create test PHP script
    cat > /tmp/index.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'ok', 'timestamp' => microtime(true)]);
EOF

    for variant in alpine debian ubuntu; do
        IMAGE="cbox-${variant}"

        CONTAINER_ID=$(docker run -d -p 8080:80 -v /tmp/index.php:/var/www/html/index.php "$IMAGE" 2>/dev/null || echo "")

        if [ -n "$CONTAINER_ID" ]; then
            # Wait for container to be ready
            sleep 3

            # Run Apache Bench if available, otherwise use curl loop
            if command -v ab &> /dev/null; then
                AB_RESULT=$(ab -n 1000 -c 10 http://localhost:8080/ 2>/dev/null | grep -E "Requests per second|Time per request" || echo "N/A")
                RPS=$(echo "$AB_RESULT" | grep "Requests per second" | awk '{print $4}')
                LATENCY=$(echo "$AB_RESULT" | grep "Time per request" | head -1 | awk '{print $4"ms"}')
                P95="N/A"
            else
                # Fallback: simple curl timing
                TOTAL_TIME=0
                for i in {1..100}; do
                    TIME=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:8080/)
                    TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc)
                done
                AVG_TIME=$(echo "scale=3; $TOTAL_TIME / 100" | bc)
                RPS=$(echo "scale=2; 100 / $TOTAL_TIME" | bc)
                LATENCY="${AVG_TIME}s"
                P95="N/A"
            fi

            echo "| $variant | ${RPS:-N/A} | ${LATENCY:-N/A} | ${P95:-N/A} |" >> "$RESULTS_DIR/http-performance-$TIMESTAMP.md"

            docker rm -f "$CONTAINER_ID" > /dev/null 2>&1
        else
            echo "| $variant | N/A | N/A | N/A |" >> "$RESULTS_DIR/http-performance-$TIMESTAMP.md"
        fi
    done

    rm -f /tmp/index.php
    echo "" >> "$RESULTS_DIR/http-performance-$TIMESTAMP.md"
    success "HTTP performance benchmark complete"
}

# Generate summary report
generate_summary() {
    info "Generating summary report..."

    cat > "$RESULTS_DIR/summary-$TIMESTAMP.md" << EOF
# Cbox Performance Benchmark Summary

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**OS Variants Tested:** Alpine, Debian, Ubuntu

## Results

EOF

    for file in "$RESULTS_DIR"/*-$TIMESTAMP.md; do
        if [ "$file" != "$RESULTS_DIR/summary-$TIMESTAMP.md" ]; then
            cat "$file" >> "$RESULTS_DIR/summary-$TIMESTAMP.md"
            echo "" >> "$RESULTS_DIR/summary-$TIMESTAMP.md"
        fi
    done

    cat >> "$RESULTS_DIR/summary-$TIMESTAMP.md" << EOF
## Recommendations

### Best for Minimal Size
Alpine Linux provides the smallest image size, ideal for:
- Microservices
- Kubernetes deployments
- Limited bandwidth scenarios

### Best for Compatibility
Debian/Ubuntu provide better compatibility with:
- Legacy applications
- Complex dependencies
- Standard glibc-based tools

### Best for Performance
Performance is generally similar across variants. Choose based on:
- Your existing infrastructure
- Team familiarity
- Ecosystem compatibility

## Notes

- Benchmarks run on GitHub Actions runners (Ubuntu-latest)
- Results may vary on different hardware
- Production performance depends on application characteristics
- Consider running benchmarks on your own infrastructure for accurate results

## Running Benchmarks Locally

\`\`\`bash
# Build all images
docker build -t cbox-alpine -f php-fpm-nginx/8.3/alpine/Dockerfile .
docker build -t cbox-debian -f php-fpm-nginx/8.3/debian/Dockerfile .
docker build -t cbox-ubuntu -f php-fpm-nginx/8.3/ubuntu/Dockerfile .

# Run benchmarks
./tests/benchmarks/run-benchmarks.sh
\`\`\`

Results will be saved to \`tests/benchmarks/results/\`.
EOF

    success "Summary report generated: $RESULTS_DIR/summary-$TIMESTAMP.md"
}

# Main execution
main() {
    echo "=========================================="
    echo "Cbox Performance Benchmarks"
    echo "=========================================="
    echo ""

    # Check if required tools are available
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker."
        exit 1
    fi

    if ! command -v bc &> /dev/null; then
        error "bc not found. Please install bc for calculations."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        info "jq not found. Installing jq for JSON parsing..."
        # Try to install jq if possible
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v brew &> /dev/null; then
            brew install jq
        else
            error "Please install jq manually: https://stedolan.github.io/jq/"
            exit 1
        fi
    fi

    benchmark_image_size
    benchmark_startup_time
    benchmark_php_performance
    benchmark_http_performance
    generate_summary

    echo ""
    echo "=========================================="
    echo "Benchmarks Complete!"
    echo "=========================================="
    echo ""
    echo "Results saved to: $RESULTS_DIR/"
    echo "Summary report: $RESULTS_DIR/summary-$TIMESTAMP.md"
}

main "$@"
