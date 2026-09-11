#!/usr/bin/env bash
# Client bootstrap: install wrk + oha, poll the SUT's schedule, measure each
# configuration, serve results on :8091. SUT_IP must be in the environment.
set -euo pipefail
mkdir -p "$HOME/cbox-bench"
exec >>$HOME/cbox-bench/client.log 2>&1
exec 9>$HOME/cbox-bench/lock; flock -n 9 || exit 0
echo "== client bootstrap $(date -u) SUT=$SUT_IP =="
docker pull -q williamyeh/wrk >/dev/null
wrk() { docker run --rm --network host williamyeh/wrk "$@"; }
if ! command -v oha >/dev/null; then
  mkdir -p "$HOME/bin"
  curl -fsSL -o "$HOME/bin/oha" https://github.com/hatoo/oha/releases/latest/download/oha-linux-amd64
  chmod +x "$HOME/bin/oha"
fi
export PATH="$HOME/bin:$PATH"
OUT=$HOME/cbox-bench/out; mkdir -p "$OUT"
( cd "$OUT" && python3 -m http.server 8091 >/dev/null 2>&1 & ) || true
: > "$OUT/results.jsonl"
curl -fsS "http://$SUT_IP:8090/digests.txt" -o "$OUT/digests.txt" || true

measure() { # name kind
  name="$1"; kind="$2"; base="http://$SUT_IP:8080"
  if [ "$kind" = laravel ]; then eps="/items"; else eps="/hello.php /work.php /static.html"; fi
  wrk -t4 -c64 -d5s "$base$(echo $eps | awk '{print $1}')" >/dev/null 2>&1
  first_ep=$(echo $eps | awk '{print $1}'); first_rps=""
  for ep in $eps; do
    for r in 1 2 3; do
      out=$(wrk -t4 -c64 -d20s --latency "$base$ep" 2>/dev/null)
      rps=$(echo "$out" | awk '/Requests\/sec/{print $2}')
      p50=$(echo "$out" | awk '/ 50%/{print $2}')
      n2=$(echo "$out" | awk '/Non-2xx/{print $4+0}'); : "${n2:=0}"
      printf '{"name":"%s","kind":"%s","ep":"%s","run":%d,"rps":%s,"p50":"%s","non2xx":%s}\n' \
        "$name" "$kind" "$ep" "$r" "${rps:-0}" "${p50:-na}" "${n2:-0}" >> "$OUT/results.jsonl"
      [ "$ep" = "$first_ep" ] && first_rps="$rps"
    done
  done
  # CO-corrected tail at ~60% of the SAME endpoint's own measured rps.
  # (v1 of this script reused $rps from the loop = the LAST endpoint, so oha
  # fired at 60% of static.html's rate against hello.php - queue explosion,
  # 20s p50s, garbage. The rate must come from the endpoint oha targets.)
  ep="$first_ep"
  cap=${first_rps%.*}; rate=$(( ${cap:-100} * 60 / 100 )); [ "$rate" -lt 50 ] && rate=50
  oha -z 45s -q "$rate" -c 64 --latency-correction --no-tui --output-format json "$base$ep" 2>/dev/null \
    | python3 -c "
import json,sys
d=json.load(sys.stdin); lp=d['latencyPercentiles']
print(json.dumps({'name':'$name','kind':'co','ep':'$ep','rate':$rate,
 'p50_ms':round(lp['p50']*1000,2),'p99_ms':round(lp['p99']*1000,2),'p999_ms':round(lp['p99.9']*1000,2),
 'success':d['summary']['successRate']}))" >> "$OUT/results.jsonl" || true
}

last=""
while true; do
  st=$(curl -fsS "http://$SUT_IP:8090/state.json" 2>/dev/null) || { sleep 5; continue; }
  name=$(echo "$st" | python3 -c "import json,sys;print(json.load(sys.stdin)['name'])" 2>/dev/null) || { sleep 5; continue; }
  phase=$(echo "$st" | python3 -c "import json,sys;print(json.load(sys.stdin)['phase'])")
  kind=$(echo "$st" | python3 -c "import json,sys;print(json.load(sys.stdin)['kind'])")
  if [ "$phase" = finished ]; then echo CLIENT-DONE; echo done > "$OUT/DONE"; break; fi
  if [ "$phase" = ready ] && [ "$name" != "$last" ]; then
    echo "measuring $name ($kind)"; last="$name"; measure "$name" "$kind"
  fi
  sleep 5
done
