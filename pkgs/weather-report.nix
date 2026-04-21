{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "weather-report";
  runtimeInputs = [ pkgs.curl pkgs.jq ];
  text = ''
    TOKEN=$(cat "$XDG_RUNTIME_DIR/telegram_bot_token")
    CHAT_ID="272730663"
    URL="https://api.telegram.org/bot$TOKEN/sendMessage"
    MESSAGE="foo"

    [[ $(curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$MESSAGE" | jq .ok) = "true" ]]
  '';
}
