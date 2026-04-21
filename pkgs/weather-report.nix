{ pkgs, pi, ... }:

pkgs.writeShellApplication {
  name = "weather-report";
  runtimeInputs = [ pkgs.curl pkgs.jq pi ];
  text = ''
    set -euo pipefail

    DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/weather-report"
    mkdir -p "$DATA_DIR"

    WEATHER=$(curl -fsS "https://wttr.in/?format=j1")
    printf '%s' "$WEATHER" > "$DATA_DIR/$(date +%F).json"

    HISTORY_FILES=()
    for i in {1..14}; do
      d=$(date -d "-$i day" +%F)
      f="$DATA_DIR/$d.json"
      [[ -f "$f" ]] && HISTORY_FILES+=("$f")
    done

    HISTORY_JSON=""
    if (( ''${#HISTORY_FILES[@]} > 0 )); then
      HISTORY_JSON=$(jq -s -c 'map(.weather[0] | {
        date: .date,
        minC: .mintempC,
        maxC: .maxtempC,
        morning: (.hourly[] | select(.time == "900") | { feelsC: .FeelsLikeC, windKmph: .windspeedKmph, rainPct: .chanceofrain }),
        evening: (.hourly[] | select(.time == "1800") | { feelsC: .FeelsLikeC, windKmph: .windspeedKmph, rainPct: .chanceofrain })
      })' "''${HISTORY_FILES[@]}")
    fi

    PROMPT="I cycle to and from work. Write a concise report (2-3 sentences) focused on how cold it will feel on the bike for the morning commute (~09:00) and evening commute (~18:00). Prioritize: feels-like/wind-chill temperature, precipitation. Call out if I need my scarf to pull over my nose, rain gear, or gloves. If recent history is provided and today's commute conditions are notably different from the recent trend, briefly mention it. Only output the report text, no preamble. Today wttr.in JSON: $WEATHER"
    if [[ -n "$HISTORY_JSON" ]]; then
      PROMPT="$PROMPT Recent history (past 14 days, daily min/max C and commute-time feels-like/wind/rain): $HISTORY_JSON"
    fi

    REPORT=$(pi -p \
      --provider morpheus \
      --model "Qwen/Qwen3.5-35B-A3B-FP8" \
      --no-tools \
      --no-session \
      "$PROMPT")

    TOKEN=$(cat "$XDG_RUNTIME_DIR/telegram_bot_token")
    CHAT_ID="272730663"
    URL="https://api.telegram.org/bot$TOKEN/sendMessage"

    [[ $(curl -fsS -X POST "$URL" --data-urlencode "chat_id=$CHAT_ID" --data-urlencode "text=$REPORT" | jq .ok) = "true" ]]
  '';
}
