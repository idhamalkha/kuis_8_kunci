#!/usr/bin/env bash
# Helper script to run / build the Flutter app with Supabase credentials.
# Usage:
# 1) Edit SUPABASE_URL and SUPABASE_ANON_KEY below OR export them in your shell.
# 2) Run: ./scripts/run_with_supabase.sh run
#    or: ./scripts/run_with_supabase.sh build-apk
#    or: ./scripts/run_with_supabase.sh build-apk-release
#
# This script is intended for use in bash (Git Bash / WSL / mingw) on Windows.

set -euo pipefail

# --- Configuration: set your values here OR export env vars before running ---
SUPABASE_URL="https://<your-project>.supabase.co"
SUPABASE_ANON_KEY="anon_xxx"

# If environment variables are set, prefer them
SUPABASE_URL=${SUPABASE_URL:-${SUPABASE_URL}}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-${SUPABASE_ANON_KEY}}

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set.\nEither edit this file or export env vars before running:" >&2
  echo "  export SUPABASE_URL='https://<your-project>.supabase.co'" >&2
  echo "  export SUPABASE_ANON_KEY='anon_xxx'" >&2
  exit 1
fi

# Common dart-define arguments
DART_DEFINES=("--dart-define=SUPABASE_URL=${SUPABASE_URL}" "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")

cmd=${1:-run}
shift || true

case "$cmd" in
  run)
    # Default target: chrome if no device
    echo "Running Flutter (dev) with Supabase credentials..."
    flutter pub get
    flutter run -d chrome ${DART_DEFINES[@]} "$@"
    ;;
  run-android)
    echo "Running on Android device/emulator with Supabase credentials..."
    flutter pub get
    flutter run -d android ${DART_DEFINES[@]} "$@"
    ;;
  build-apk)
    echo "Building debug APK (use for quick tests)..."
    flutter pub get
    flutter build apk ${DART_DEFINES[@]} --debug
    ;;
  build-apk-release)
    echo "Building release APK..."
    flutter pub get
    flutter build apk --release ${DART_DEFINES[@]}
    ;;
  deploy-functions)
    echo "Deploying Supabase Edge Functions (requires supabase CLI and service role key set as SUPABASE_SERVICE_ROLE_KEY)"
    if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
      echo "Please export SUPABASE_SERVICE_ROLE_KEY before deploying functions: export SUPABASE_SERVICE_ROLE_KEY='service_role_xxx'" >&2
      exit 1
    fi
    # Example deploy list - adjust function names if you changed them
    supabase functions deploy start_quiz --project-ref <your-project-ref>
    supabase functions deploy get_question --project-ref <your-project-ref>
    supabase functions deploy submit_answer --project-ref <your-project-ref>
    supabase functions deploy get_leaderboard --project-ref <your-project-ref>
    ;;
  help|--help|-h)
    echo "Usage: $0 {run|run-android|build-apk|build-apk-release|deploy-functions}";
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Run $0 help for usage." >&2
    exit 2
    ;;
esac

exit 0
