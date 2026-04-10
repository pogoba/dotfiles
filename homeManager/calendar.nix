# Syncs Nextcloud calendars via vdirsyncer, displays them with khal.
# The khal-next Noctalia bar plugin is configured in noctalia.nix.
#
# Adding a new calendar:
#   1. Get the Nextcloud app password: Nextcloud > Settings > Security > Devices & sessions
#   2. List remote calendars and their UUIDs:
#        curl -s -u "peter:APP_PASSWORD" -X PROPFIND -H "Depth: 1" \
#          -H "Content-Type: application/xml" \
#          -d '<?xml version="1.0"?><propfind xmlns="DAV:"><prop><displayname/></prop></propfind>' \
#          "https://nextcloud.pogobanane.de/remote.php/dav/calendars/peter/"
#   3. Add an entry to `collections` below: ["local_name", "REMOTE_UUID", "local_name"]
#   4. Add a matching [[local_name]] section to the khal config below
#   5. Apply home-manager, then:
#        rm -rf ~/.vdirsyncer/status/
#        mkdir -p ~/.local/share/calendars/local_name
#        vdirsyncer discover
#        vdirsyncer sync
{ pkgs, ... }:
let
  calendarSyncScript = pkgs.writeShellScriptBin "calendar-sync" ''
    export PATH="${pkgs.vdirsyncer}/bin:$PATH"
    vdirsyncer sync
  '';
in
{
  home.packages = [
    pkgs.khal
    pkgs.vdirsyncer
  ];

  home.file.".config/vdirsyncer/config".text = ''
[general]
status_path = "~/.vdirsyncer/status/"

[pair calendar]
a = "nextcloud_remote"
b = "calendar_local"
collections = [["private", "24EFA1B6-A276-4EF0-BB7E-B1AA8D713E56", "private"], ["important", "901D7D14-5183-4331-9EA7-92745DD2360F", "important"], ["muellabfuhr", "76375FDD-9549-43BE-BDE8-7FC100DF0199", "muellabfuhr"], ["37c3", "E256DA37-5CF3-441C-8199-58CB1BBBE899", "37c3"], ["contact_birthdays", "contact_birthdays", "contact_birthdays"]]

[storage calendar_local]
type = "filesystem"
path = "~/.local/share/calendars/"
fileext = ".ics"

[storage nextcloud_remote]
type = "caldav"
url = "https://nextcloud.pogobanane.de/remote.php/dav"
username = "peter"
# TODO: replace with your actual credential command
password.fetch = ["command", "cat", "~/.ssh/nextcloud-vdirsyncer-calendar"]
  '';

  home.file.".config/khal/config".text = ''
[calendars]

[[private]]
path = ~/.local/share/calendars/private/
type = calendar
color = light blue

[[important]]
path = ~/.local/share/calendars/important/
type = calendar
color = light red

[[muellabfuhr]]
path = ~/.local/share/calendars/muellabfuhr/
type = calendar
color = light green

[[37c3]]
path = ~/.local/share/calendars/37c3/
type = calendar
color = light magenta

[[contact_birthdays]]
path = ~/.local/share/calendars/contact_birthdays/
type = calendar
color = light cyan

[locale]
timeformat = %H:%M
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M

[default]
default_calendar = private
  '';

  systemd.user.services.calendar-sync = {
    Unit = {
      Description = "Sync calendars with vdirsyncer";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${calendarSyncScript}/bin/calendar-sync";
    };
  };

  systemd.user.timers.calendar-sync = {
    Unit.Description = "Sync calendars regularly";
    Timer = {
      OnCalendar = "*:0/15";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
