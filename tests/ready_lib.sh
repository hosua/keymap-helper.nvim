# Sourced by the live scripts after smoke_start. A fixed sleep is not enough:
# the copied real config took about 6 seconds to load on a busy box.

# live_wait_nvim [timeout_s]: poll until :KeymapHelper exists in the session.
live_wait_nvim() {
  local limit=${1:-30} i
  for ((i = 0; i < limit; i++)); do
    smoke_keys ':echo "rdy=" . exists(":KeymapHelper")' Enter
    if smoke_screen | grep -q 'rdy=2'; then
      return 0
    fi
    sleep 1
  done
  echo "FAIL  nvim not ready after ${limit}s (:KeymapHelper never appeared):"
  smoke_screen | sed 's/^/        |/'
  exit 1
}

# live_wait_screen REGEX [timeout_s]: poll until the screen matches.
live_wait_screen() {
  local re=$1 limit=${2:-30} i
  for ((i = 0; i < limit; i++)); do
    smoke_screen | grep -qE -- "${re}" && return 0
    sleep 1
  done
  echo "FAIL  /${re}/ never appeared within ${limit}s:"
  smoke_screen | sed 's/^/        |/'
  exit 1
}
