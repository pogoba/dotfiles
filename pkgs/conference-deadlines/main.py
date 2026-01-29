#!/usr/bin/env python3
import subprocess
import json
import traceback
import shlex
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from urllib.parse import urlparse
from dataclasses import dataclass
from enum import Enum
import tempfile
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.firefox.options import Options as FirefoxOptions
import time
import os
import base64
from pathlib import Path

CACHE_DIR = Path(__file__).parent / "history"

# Optional tqdm for progress bar
try:
    from tqdm import tqdm
    def progress_write(msg):
        tqdm.write(msg, file=sys.stderr)
except ImportError:
    tqdm = None
    def progress_write(msg):
        print(msg, file=sys.stderr)

# Global cost and call tracking
_total_cost = 0.0
_total_calls = 0
_stats_lock = threading.Lock()


class Crawler:
    """Thread-safe browser manager for saving pages as PDF."""
    # TODO separate worker. Generate jobs for other workers each time this one produces output.

    def __init__(self):
        self._lock = threading.Lock()
        self._driver = None

    def _get_driver(self):
        if self._driver is None:
            options = FirefoxOptions()
            options.add_argument("--headless")
            self._driver = webdriver.Firefox(options=options)
        return self._driver

    def save_pdf(self, url: str, filepath: str, timeout: int = 30):
        with self._lock:
            driver = self._get_driver()
            driver.get(url)

            # Wait for page to fully load
            WebDriverWait(driver, timeout).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )

            time.sleep(5) # give time for js rendering

            # Print to PDF
            pdf_base64 = driver.print_page()
            with open(filepath, "wb") as f:
                f.write(base64.b64decode(pdf_base64))

    def quit(self):
        if self._driver:
            self._driver.quit()
            self._driver = None


_crawler = Crawler()

# TODO ctrl c doesn't stop it on first try
# TODO failures in threads don't stop everything.
# TODO ATC has a wrong 2026 entry that breaks the prediction hint
# TODO check correctness of conext eurosy and fast
# TODO add a menu to select and deselect conferences
# TODO remove javascript for hover or improve it.
# TODO understand other deadlines types as well and add gnatt charts [submission, notification]

# Manual predictions from private intelligence, keyed by (name, year, cycle)
# These override automatic predictions
PREDICTION_HINTS = {
    # ("SIGCOMM", 2027, ""): "2027-01-30",
    ("ATC", 2026, "Based on user submitted information"): "2026-06-10"
}

FROM_YEAR=2020
NOW=2026

# List of (name, year, url) tuples
CONFERENCES = [
    *[("SIGCOMM", y, f"https://conferences.sigcomm.org/sigcomm/{y}/cfp/") for y in range(2024, NOW+1)],
    *[("EuroSys", y, f"https://{y}.eurosys.org/cfp.html#calls") for y in range(2025, NOW+1)],
    *[("NSDI", y, f"https://www.usenix.org/conference/nsdi{y % 100:02d}/call-for-papers") for y in range(2012, NOW+1)],
    *[("SoCC", y, f"https://acmsocc.org/{y}/papers.html") for y in range(2015, NOW+1)],
    *[("SOSP", y, f"https://sigops.org/s/conferences/sosp/{y}/cfp.html") for y in range(2024, NOW+1)],
    *[("HotOS", y, f"https://sigops.org/s/conferences/hotos/{y}/cfp.html") for y in range(2023, NOW+1)],
    *[("ASPLOS", y, f"https://www.asplos-conference.org/asplos{y}/cfp/") for y in range(2024, NOW+1)],
    *[("FAST", y, f"https://www.usenix.org/conference/fast{y % 100:02d}/call-for-papers") for y in range(2013, NOW+1)],
    *[("NDSS", y, f"https://www.ndss-symposium.org/ndss{y}/submissions/call-for-papers/") for y in range(2017, NOW+1)],
    *[("Middleware", y, f"https://middleware-conf.github.io/{y}/calls/call-for-research-papers/") for y in range(2023, NOW+1)],
    *[("APSys", y, f"https://apsys{y}.github.io/call_for_papers.html") for y in [2025]],
    # APSys needs new links
    *[("HotNets", y, f"https://conferences.sigcomm.org/hotnets/{y}/cfp.html") for y in range(2005, NOW+1)],
    *[("ATC", y, f"https://www.usenix.org/conference/atc{y % 100:02d}/call-for-papers") for y in range(2013, NOW+1)],
    *[("OSDI", y, f"https://www.usenix.org/conference/osdi{y % 100:02d}/call-for-papers") for y in range(2018, NOW+1)],

    *[("NINES", 2026, "https://nines-conference.org/cfp")],

    # # conext server often returns randomly broken content. Also claude refuses to evaluate the javascript needed to read the website.
    *[("CoNEXT", y, f"https://conferences2.sigcomm.org/co-next/{y}/#!/cfp") for y in range(2012, NOW+1)],
    *[("SOSP", y, f"https://sigops.org/s/conferences/sosp/{y}/cfp.html") for y in range(2026, NOW+1)],
]


def conf_label(name: str, year: int) -> str:
    """Generate display label like SIGCOMM'26."""
    return f"{name}'{year % 100:02d}"

CYCLES_SCHEMA = {
    "type": "object",
    "properties": {
        "cycles": {
            "type": "array",
            "items": {"type": "string"},
            "description": "List of submission cycle labels. When cycles are not announced yet, put []. Otherwise put [''] for single cycle or e.g. ['Spring', 'Fall']."
        }
    },
    "required": ["cycles"]
}

SINGLE_DEADLINE_SCHEMA = {
    "type": "object",
    "properties": {
        "is_announced": {
            "type": "boolean",
            "description": "Whether the deadline time is announced on the website."
        },
        "date": {
            "type": "string",
            "description": "ISO 8601 date, e.g. 2026-01-30"
        },
        "time": {
            "type": "string",
            "description": "Time as HH:MM:SS, e.g. 23:59:59"
        },
        "timezone": {
            "type": "string",
            "description": "Timezone as stated on website, e.g. AoE, PST, UTC"
        },
        "utc_offset": {
            "type": "integer",
            "description": "Timezone offset from UTC in hours, e.g. -12 for AoE, -8 for PST, 0 for UTC"
        },
        "raw_string": {
            "type": "string",
            "description": "Exact quote from website containing the deadline type and date, e.g. 'Abstract registration: Friday, January 30, 2026 AoE'"
        }
    },
    "required": ["is_announced", "date", "time", "timezone", "utc_offset", "raw_string"]
}

OTHER_DEADLINES_SCHEMA = {
    "type": "object",
    "properties": {
        "deadlines": {
            "type": "array",
            "items": SINGLE_DEADLINE_SCHEMA
        }
    },
    "required": ["deadlines"]
}

class DeadlineType(Enum):
    SUBMISSION = "submission"
    UNKNOWN = "unknown"

@dataclass
class Deadline:
    """
    If a deadline is not announced yet, or if any data field cannot be determined, is_announce must be False and the other fields must be empty.
    """
    is_announced: bool
    is_valid: bool
    deadline_type: DeadlineType

    date: str
    time: str
    timezone: str
    utc_offset: int
    raw_string: str

    @classmethod
    def invalid(cls, deadline_type: DeadlineType) -> "Deadline":
        return Deadline(
            is_announced=False,
            is_valid=False,
            deadline_type=deadline_type,
            date="",
            time="",
            timezone="",
            utc_offset=0,
            raw_string="",
        )

    @classmethod
    def from_json(cls, item: dict, deadline_type: DeadlineType) -> "Deadline":
        assert isinstance(item, dict)
        assert isinstance(deadline_type, DeadlineType)
        is_valid = validate_deadline(item) is None
        deadline = Deadline(
            is_announced=item.get("is_announced"),
            is_valid=is_valid,
            deadline_type=deadline_type,
            date=item.get("date"),
            time=item.get("time"),
            timezone=item.get("timezone"),
            utc_offset=item.get("utc_offset"),
            raw_string=item.get("raw_string"),
        )
        return deadline

    def time_equals(self, other: "Deadline") -> bool:
        return (
            self.date == other.date and
            self.time == other.time and
            self.timezone == other.timezone and
            self.utc_offset == other.utc_offset
        )



class ConferenceEvent:
    """
    """
    name: str
    year: int
    url: str

    cycles: list[str] # [] if not announced; [ "" ] if single cycle

    deadlines: dict[str, list[Deadline]] # cycle -> deadline

    def __init__(self, name: str, year: int, url: str):
        self.name = name
        self.year = year
        self.url = url
        self.cycles_announced = False
        self.cycles = []
        self.deadlines = dict()

    def set_cycles(self, cycles: list[str]):
        # assert that contract from json scheme is fulfilled
        assert isinstance(cycles, list)
        assert all(isinstance(c, str) for c in cycles)

        self.cycles = cycles

    def set_deadline(self, cycle: str, deadline: Deadline):
        """
        cycle: "" if single cycle
        """
        assert isinstance(cycle, str)
        assert isinstance(deadline, Deadline)
        assert isinstance(deadline.deadline_type, DeadlineType)

        # TODO dont throw, but invalidate deadline
        if cycle not in self.cycles:
            ConsistencyError(f"Cycle '{cycle}' not in announced cycles {self.cycles}")
        if cycle not in self.deadlines:
            self.deadlines[cycle] = []
        self.deadlines[cycle].append(deadline)

    def get_deadline(self, cycle: str, deadline_type: DeadlineType) -> Deadline | None:
        for deadline in self.deadlines.get(cycle, []):
            if deadline.deadline_type == deadline_type:
                return deadline
        return None

    def validate(self):
        # TODO dont throw, but invalidate ConferenceEvent
        if len(self.cycles) == 0 and len(self.deadlines.keys()) > 0:
            raise ConsistencyError("Deadlines exist but no cycles announced")
        if not self.cycles_announced and len(self.cycles) != 0:
            raise ConsistencyError("Cycles announced flag is False but cycles list is not empty")
        has_submission = any(
            d.deadline_type == DeadlineType.SUBMISSION
            for cycle_deadlines in self.deadlines.values()
            for d in cycle_deadlines
        )
        if not has_submission:
            # required submission deadline missing (should be at least Deadline(is_announced=False))
            raise ConsistencyError("Submission deadline missing")
        # maybe validate each deadline?

    def to_dict(self) -> dict:
        """
        Returns:
            {
                "cycles": ["Spring", "Fall"],
                "deadlines": [
                    {
                        "cycle": "Spring",
                        "deadline_type": "submission",  # "submission" | "unknown"
                        "date": "YYYY-MM-DD",
                        "time": "HH:MM:SS",
                        "timezone": "AoE",
                        "utc_offset": -12,
                        "raw_string": "...",
                        "valid": true
                    },
                    ...
                ]
            }
        """
        return {
            "cycles": self.cycles,
            "deadlines": [
                {
                    "cycle": cycle,
                    "deadline_type": deadline.deadline_type.value,
                    "date": deadline.date,
                    "time": deadline.time,
                    "timezone": deadline.timezone,
                    "utc_offset": deadline.utc_offset,
                    "raw_string": deadline.raw_string,
                    "valid": deadline.is_valid and deadline.is_announced,
                }
                for cycle, cycle_deadlines in self.deadlines.items()
                for deadline in cycle_deadlines
            ]
        }




class ConsistencyError(Exception):
    """Raised when inconsistencies are found in deadline data that are most likely caused by LLM fuzzyness."""
    pass

class ClaudeQueryError(Exception):
    """Raised when a Claude query fails to return expected output."""
    pass

class ClaudeUsageLimitError(Exception):
    """Raised when Claude usage limit is hit."""
    pass


def validate_deadline(item: dict) -> str | None:
    """Validate a deadline item. Returns error message or None if valid."""
    # Validate date (ISO 8601: YYYY-MM-DD)
    try:
        datetime.strptime(item["date"], "%Y-%m-%d")
    except (ValueError, KeyError) as e:
        return f"Invalid date '{item.get('date')}': {e}"

    # Validate time (HH:MM:SS)
    try:
        datetime.strptime(item["time"], "%H:%M:%S")
    except (ValueError, KeyError) as e:
        return f"Invalid time '{item.get('time')}': {e}"

    # Validate utc_offset (-12 to +14)
    utc_offset = item.get("utc_offset")
    if not isinstance(utc_offset, int):
        return f"utc_offset must be int, got {type(utc_offset).__name__}"
    if not (-12 <= utc_offset <= 14):
        return f"utc_offset {utc_offset} out of range [-12, +14]"

    return None


def run_claude(
    prompt: str,
    schema: str = None,
    allowed_tools: str = None,
    session_id: str = None,
) -> dict:
    """Run claude and return parsed JSON output."""
    cmd = [
        "claude",
        "-p", prompt,
        "--output-format", "json",
    ]
    if schema:
        cmd.extend(["--json-schema", schema])
    if allowed_tools:
        cmd.extend(["--allowedTools", allowed_tools])
    if session_id:
        cmd.extend(["--resume", session_id])

    # print(shlex.join(cmd), file=sys.stderr)
    # print(file=sys.stderr)

    for _ in range(4):
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
        )
        if "An update to our Consumer Terms and Privacy Policy has taken effect" in result.stderr:
            # is a random message to prevent automated use?
            progress_write(f"Retrying Claude command after privacy policy message: {shlex.join(cmd)}")
        elif "error_during_execution" in getattr(result, "subtype", ""):
            progress_write(f"Retrying Claude command after claude-cli error: {'\n'.join(result.errors)}")
        else:
            break

    if result.returncode != 0:
        try:
            output = json.loads(result.stdout)
        except Exception:
            pass
        else:
            if "You've hit your limit" in output.get("result", ""):
                raise ClaudeUsageLimitError()
        progress_write(f"Command failed: {shlex.join(cmd)}")
        progress_write(f"stdout: {result.stdout}")
        progress_write(f"stderr: {result.stderr}")
        result.check_returncode()  # Raise CalledProcessError

    output = json.loads(result.stdout)

    # Track cost and calls
    global _total_cost, _total_calls
    cost = output.get("total_cost_usd", 0.0)

    with _stats_lock:
        _total_cost += cost
        _total_calls += 1

    return output


def fetch_deadlines(name: str, url: str) -> ConferenceEvent:
    """Fetch and extract deadlines for a conference.

    Args:
        name: Display name like "SIGCOMM'26"
        url: CFP page URL
    """
    domain = urlparse(url).netloc
    conference = ConferenceEvent(name, 0, url) # TODO year
    progress_write(f"  {name}: {url}")

    progress_write(f"  {name}: Fetching website...")
    downloads_dir = os.path.join(CACHE_DIR, "downloads")
    os.makedirs(downloads_dir, exist_ok=True)
    pdf_path = os.path.join(downloads_dir, f"{name}.pdf")
    _crawler.save_pdf(url, pdf_path) # TODO handle failures

    # Step 1: Fetch the URL content
    progress_write(f"  {name}: Reading website content...")
    fetch_output = run_claude(
        prompt=f"Read the {pdf_path} PDF of the {name} website and summarize the page content",
        allowed_tools=f"Read({pdf_path})",
    )
    session_id = fetch_output.get("session_id")
    if not session_id:
        raise ClaudeQueryError("No session_id returned from fetch")

    page_content = fetch_output.get("result", "")
    if not page_content:
        raise ClaudeQueryError("Failed to fetch page content")

    # Step 2: Extract submission cycles
    progress_write(f"  {name}: Extracting submission cycles...")
    cycles_output = run_claude(
        prompt="What submission/review cycles does this conference website announce? E.g. Spring/Fall, Round 1/2/3, just a single cycle, or none if not announced. Return cycle labels as array.",
        schema=json.dumps(CYCLES_SCHEMA),
        session_id=session_id,
    )
    maybe_cycles = cycles_output.get("structured_output", {}).get("cycles")
    if maybe_cycles is None:
        progress_write(f"  {name}: {cycles_output}")
    conference.set_cycles(cycles_output.get("structured_output", {}).get("cycles"))

    # Step 3: Extract submission deadline for each cycle
    progress_write(f"  {name}: Extracting submission deadlines...")
    for cycle in conference.cycles:
        cycle_prompt = f"Extract the paper submission deadline for the {cycle} cycle" if cycle else "Extract the paper submission deadline"
        sub_output = run_claude(
            prompt=cycle_prompt,
            schema=json.dumps(SINGLE_DEADLINE_SCHEMA),
            session_id=session_id,
        )
        sub_deadline = sub_output.get("structured_output")
        if sub_deadline:
            conference.set_deadline(cycle, Deadline.from_json(sub_deadline, DeadlineType.SUBMISSION))
        else:
            progress_write(f"  {name}: WARNING: {sub_output}")
            conference.set_deadline(cycle, Deadline.invalid(DeadlineType.SUBMISSION))

    # Step 4: Extract all deadlines for each cycle
    progress_write(f"  {name}: Extracting all deadlines...")
    for cycle in conference.cycles:
        cycle_prompt = f"Extract all deadlines for the {cycle} cycle" if cycle else "Extract all deadlines"
        all_output = run_claude(
            prompt=cycle_prompt,
            schema=json.dumps(OTHER_DEADLINES_SCHEMA),
            session_id=session_id,
        )
        cycle_deadlines = all_output.get("structured_output", {}).get("deadlines", [])
        for d in cycle_deadlines:
            conference.set_deadline(cycle, Deadline.from_json(d, DeadlineType.UNKNOWN))

    # Merge - replace matching entries with submission deadlines
    progress_write(f"  {name}: Validating results...")
    for cycle in conference.cycles:
        deadlines = conference.deadlines.get(cycle, [])
        submission: Deadline = [ d for d in deadlines if d.deadline_type == DeadlineType.SUBMISSION ][0]
        submission_duplicates: list[Deadline] = [ d for d in deadlines if d.deadline_type != DeadlineType.SUBMISSION and submission.time_equals(d) ]
        _ = [ deadlines.remove(d) for d in submission_duplicates ]
        duplicates = len(submission_duplicates)
        if duplicates != 1:
            submission.is_valid = False
            progress_write(f"  {name}: WARNING: hsubmission deadline ({submission.date}, {submission.time}) doesnt have exactly one ({duplicates}) duplicates in all_deadlines")
            # raise ClaudeQueryError(
            #     f"Submission deadline ({submission.date}, {submission.time}) not found in all_deadlines" # marker
            # )

    return conference


def print_deadline_table(results: dict[str, ConferenceEvent]):
    """Sort conferences by submission deadline and print as table."""
    # Flatten: (conf_name, cycle, deadline) for each submission deadline
    rows = []
    invalid = []

    for conf, data in results.items():
        for cycle, cycle_deadlines in data.deadlines.items():
            for deadline in cycle_deadlines:
                if deadline.deadline_type != DeadlineType.SUBMISSION:
                    continue
                if deadline.is_valid:
                    # Add cycle suffix if multiple cycles
                    label = f"{conf} ({cycle})" if cycle else conf
                    rows.append((label, deadline.date))
                else:
                    invalid.append(conf)

    if invalid:
        print(f"Invalid: {', '.join(set(invalid))}")
        print()

    rows.sort(key=lambda r: r[1])

    # Header
    print(f"{'Month':<10} {'Conference':<25} {'Deadline':<12}")
    print("-" * 45)

    # Rows
    for conf, date in rows:
        month = date[:7]  # YYYY-MM
        print(f"{month:<10} {conf:<25} {date:<12}")


def predict_deadlines(rows: list, target_year: int) -> list:
    """Predict deadlines for target_year based on historical patterns.

    Uses cycle-aware prediction: only considers the consecutive block of years
    (going backwards from latest) that have the same cycle setup as the latest year.

    Args:
        rows: list of (name, year, cycle, date, predicted, json_data, url) tuples
        target_year: year to predict for

    Returns list of (name, year, cycle, date, predicted=True, json_data=None, url="") tuples.
    """
    from collections import defaultdict

    # Group by conference name -> year -> list of (cycle, date)
    by_conf = defaultdict(lambda: defaultdict(list))
    for name, year, cycle, date, _, *_ in rows:
        by_conf[name][year].append((cycle, date))

    predictions = []
    for name, year_data in by_conf.items():
        years_present = set(year_data.keys())
        if target_year in years_present:
            continue  # Already have data for target year

        # Filter to years with valid submission deadlines only
        # A valid deadline should be within 2 years before the conference year
        def is_valid_entry(conf_year, date_str):
            if not date_str:
                return False
            try:
                deadline_year = int(date_str[:4])
                return conf_year - 2 <= deadline_year <= conf_year
            except (ValueError, IndexError):
                return False

        valid_year_data = {
            y: [(c, d) for c, d in entries if is_valid_entry(y, d)]
            for y, entries in year_data.items()
        }
        valid_year_data = {y: entries for y, entries in valid_year_data.items() if entries}

        if not valid_year_data:
            continue

        # Get latest valid year and its cycle setup
        latest_year = max(valid_year_data.keys())
        latest_cycles = frozenset(c for c, _ in valid_year_data[latest_year])

        # Find block of years with same cycle setup (going backwards, ignoring gaps)
        valid_years = []
        other_cycle_years = []  # Years with different cycle setup
        found_mismatch = False
        for y in sorted(valid_year_data.keys(), reverse=True):
            year_cycles = frozenset(c for c, _ in valid_year_data[y])
            if year_cycles != latest_cycles:
                found_mismatch = True
            if found_mismatch:
                other_cycle_years.append(y)
            else:
                valid_years.append(y)

        if not valid_years:
            continue

        # Collect other cycle deadlines for tooltip
        other_cycle_history = []
        for y in other_cycle_years:
            for c, d in valid_year_data[y]:
                label = f"{conf_label(name, y)}"
                if c:
                    label += f" ({c})"
                other_cycle_history.append(f"{label}: {d}")

        # For each cycle in latest setup, predict using most recent valid year
        for cycle in latest_cycles:
            # Check for manual hint first
            hint_key = (name, target_year, cycle)
            if hint_key in PREDICTION_HINTS:
                predictions.append((name, target_year, cycle, PREDICTION_HINTS[hint_key], True, {"user_provided": True}, ""))
                continue

            # Collect all dates for this cycle from valid years
            cycle_dates = []
            history = []
            for y in valid_years:
                for c, d in valid_year_data[y]:
                    if c == cycle:
                        try:
                            dt = datetime.strptime(d, "%Y-%m-%d")
                            # Calculate days from start of conference year
                            conf_year_start = datetime(y, 1, 1)
                            days_offset = (dt - conf_year_start).days
                            cycle_dates.append(days_offset)
                            history.append(f"{conf_label(name, y)}: {d}")
                        except ValueError:
                            pass

            if not cycle_dates:
                continue

            # Average the day offsets and apply to target year
            avg_days = sum(cycle_dates) // len(cycle_dates)
            max_dev = max(abs(d - avg_days) for d in cycle_dates)
            try:
                predicted_dt = datetime(target_year, 1, 1) + timedelta(days=avg_days)
                predicted_date = predicted_dt.strftime("%Y-%m-%d")
                pred_info = {
                    "history": "\n".join(sorted(history)),
                    "other_cycles": "\n".join(sorted(other_cycle_history)) if other_cycle_history else "",
                    "max_dev": max_dev,
                    "count": len(cycle_dates),
                }
                predictions.append((name, target_year, cycle, predicted_date, True, pred_info, ""))
            except ValueError:
                pass  # Skip if date is invalid

    return predictions


def write_html_table(results: dict[str, ConferenceEvent], filepath: str):
    """Write deadline table as HTML file."""

    # Flatten: (name, year, cycle, date, predicted, deadline_json, url) for each submission deadline
    rows = []
    for conf, data in results.items():
        name = data.name
        year = data.year
        url = data.url

        for cycle, cycle_deadlines in data.deadlines.items():
            for deadline in cycle_deadlines:
                if deadline.deadline_type != DeadlineType.SUBMISSION:
                    continue
                if not deadline.is_valid:
                    continue
                # Convert Deadline to dict for tooltip compatibility
                d_dict = {
                    "date": deadline.date,
                    "time": deadline.time,
                    "timezone": deadline.timezone,
                    "utc_offset": deadline.utc_offset,
                    "raw_string": deadline.raw_string,
                }
                rows.append((name, year, cycle, deadline.date, False, d_dict, url))

    # Add predictions for NOW and NOW+1 years
    predictions = predict_deadlines(rows, NOW)
    rows.extend(predictions)
    predictions_next = predict_deadlines(rows, NOW + 1)
    # Only include next year's predictions if deadline falls in current year
    rows.extend(p for p in predictions_next if p[3].startswith(str(NOW)))

    # Apply prediction hints as overrides (replace existing rows or add new ones)
    for (hint_name, hint_year, hint_cycle), hint_date in PREDICTION_HINTS.items():
        # Remove any existing row for this (name, year, cycle)
        rows = [r for r in rows if not (r[0] == hint_name and r[1] == hint_year and r[2] == hint_cycle)]
        # Add the hint row
        rows.append((hint_name, hint_year, hint_cycle, hint_date, True, None, ""))

    rows.sort(key=lambda r: r[3])  # Sort by date

    # Collect unique conference names for filter
    conf_names = sorted(set(r[0] for r in rows))

    now = datetime.now().strftime("%Y-%m-%d")
    html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Conference Deadlines</title>
    <style>
        body {{ max-width: 60em; margin: 0 auto; padding: 20px; font-family: sans-serif; }}
        table {{ border-collapse: collapse; width: 100%; margin-bottom: 2em; table-layout: fixed; }}
        th, td {{ border: 1px solid #ccc; padding: 8px; text-align: left; vertical-align: top; }}
        th:nth-child(1), td:nth-child(1) {{ width: 13%; }}
        th:nth-child(2), td:nth-child(2) {{ width: 55%; }}
        th:nth-child(3), td:nth-child(3) {{ width: 32%; }}
        th {{ background: #f0f0f0; }}
        .predicted {{ font-style: italic; color: #666; }}
        #conf-filter {{ display: flex; flex-wrap: wrap; gap: 0.5em 1.5em; margin: 0.5em 0; }}
        #conf-filter label {{ white-space: nowrap; }}
        summary {{ cursor: pointer; }}
    </style>
</head>
<body>
    <h1>Conference Deadlines</h1>
    <p>
        Last updated: {now}<br>
        Conference sites are crawled by an LLM, so be wary of errors.<br>
        Deadline predictions are in gray.<br>
        Hover the conference name for more info.<br>
    </p>
    <details>
        <summary>Filter conferences</summary>
        <div id="conf-filter">
"""
    for conf in conf_names:
        html += f'            <label><input type="checkbox" value="{conf}" checked> {conf}</label>\n'
    html += """        </div>
    </details>
"""
    # Group by deadline year (descending), then by month
    years = {}
    for row in rows:
        y = row[3][:4]  # year from deadline date
        years.setdefault(y, []).append(row)
    for year in sorted(years.keys(), reverse=True):
        year_rows = years[year]
        html += f"    <h2>{year}</h2>\n"
        html += """    <table>
        <tr><th>Month</th><th>Conference</th><th>Deadline</th></tr>
"""
        # Group rows by month
        rows_by_month = {}
        for row in year_rows:
            month = row[3][:7]
            rows_by_month.setdefault(month, []).append(row)

        # Iterate through all 12 months
        for m in range(1, 13):
            month = f"{year}-{m:02d}"
            month_name = datetime.strptime(month, "%Y-%m").strftime("%B")
            group_rows = rows_by_month.get(month, [])
            if not group_rows:
                html += f'        <tr><td>{month_name}</td><td></td><td></td></tr>\n'
                continue
            for i, (name, yr, cycle, date, predicted, json_data, url) in enumerate(group_rows):
                label = conf_label(name, yr)
                if cycle:
                    label += f" ({cycle})"
                cls = ' class="predicted"' if predicted else ""
                if url:
                    label_html = f'<a href="{url}">{label}</a>'
                else:
                    label_html = label
                if isinstance(json_data, dict) and json_data.get("user_provided"):
                    tooltip = "User provided"
                    date_display = f"{date} (user provided)"
                elif isinstance(json_data, dict) and "history" in json_data:
                    tooltip = json_data["history"]
                    if json_data.get("other_cycles"):
                        tooltip += "\n\nOlder deadlines with other submission cycle:\n" + json_data["other_cycles"]
                    warn = "⚠ " if json_data["max_dev"] > 15 or json_data["count"] == 1 else ""
                    date_display = f"{warn}{date} (±{json_data['max_dev']}d, n={json_data['count']})"
                elif isinstance(json_data, dict):
                    tooltip = json.dumps(json_data, indent=2)
                    date_display = f"{date} (predicted)" if predicted else date
                elif json_data:
                    tooltip = json.dumps(json_data, indent=2)
                    date_display = f"{date} (predicted)" if predicted else date
                else:
                    tooltip = "Predicted" if predicted else ""
                    date_display = f"{date} (predicted)" if predicted else date
                tooltip_escaped = tooltip.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;").replace("\n", "&#10;")
                html += f'        <tr data-conf="{name}"><td>{month_name}</td><td{cls} title="{tooltip_escaped}">{label_html}</td><td{cls}>{date_display}</td></tr>\n'
        html += "    </table>\n"

    html += """    <script>
    document.querySelectorAll('#conf-filter input').forEach(cb => {
        cb.addEventListener('change', applyFilter);
        applyFilter();
        function applyFilter() {
            const conf = cb.value;
            document.querySelectorAll(`tr[data-conf="${conf}"]`).forEach(tr => {
                tr.style.display = cb.checked ? '' : 'none';
            });
        }
    });
    </script>
    <footer style="margin-top: 2em; color: #666; font-size: 0.9em; text-align: center;">
        <a href="https://github.com/pogobanane/dotfiles/tree/master/pkgs/conference-deadlines">Source</a>
        Inspired by:
        <a href="https://dants.github.io/index_sysvenues_deadline.html">Dan Tsafrir</a>,
        <a href="https://www.os.is.s.u-tokyo.ac.jp/conf/">Takahiro Shinagawa</a>
    </footer>
</body>
</html>
"""
    with open(filepath, "w") as f:
        f.write(html)

    print(f"Wrote {filepath}", file=sys.stderr)


def main():
    results = {}
    try:
        with ThreadPoolExecutor(max_workers=1) as executor:
            futures = {
                executor.submit(fetch_deadlines, conf_label(name, year), url): (conf_label(name, year), name, year, url)
                for name, year, url in CONFERENCES
                if year >= FROM_YEAR
            }
            futures_iter = as_completed(futures)
            if tqdm:
                futures_iter = tqdm(futures_iter, total=len(futures), desc="Fetching", file=sys.stderr)

            for future in futures_iter:
                label, name, year, url = futures[future]
                try:
                    result = future.result()  # ConferenceEvent
                    result.name = name
                    result.year = year
                    results[label] = result
                    progress_write(f"  {label}: OK")
                except ClaudeUsageLimitError as e:
                    print("Aborting due to API limits...", flush=True)
                    executor.shutdown(wait=True, cancel_futures=True)
                    raise e
                except Exception as e:
                    progress_write(f"  {label}: Error - {e}")
                    [ progress_write(f"  {label}: {line}") for line in traceback.format_exception(e) ]
    except Exception as e:
        _crawler.quit()
        raise e
    else:
        # Write JSON cache
        with open("/tmp/deadlines.json", "w") as f:
            result_dict = { k: v.to_dict() for k, v in results.items() }
            json.dump(result_dict, f, indent=2)
        print("Wrote /tmp/deadlines.json", file=sys.stderr)

        print_deadline_table(results)
        write_html_table(results, "/tmp/deadlines.html")

        print(f"Total: {_total_calls} API calls, ${_total_cost:.4f}", file=sys.stderr)
        print("This may account to up to 15% of a claude session (resets 4 hourly).")
        _crawler.quit()



def render_only():
    """Re-render HTML from cached JSON."""
    with open("/tmp/deadlines.json") as f:
        results = json.load(f)
    print_deadline_table(results)
    write_html_table(results, "/tmp/deadlines.html")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--render":
        render_only()
    else:
        main()
