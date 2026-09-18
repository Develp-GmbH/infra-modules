#!/usr/bin/env python3

import requests
import os
import json
import sys
import time
import logging as log
from pathlib import Path
from argparse import ArgumentParser
from datetime import datetime

GH_URL = 'https://github.com'
GH_API_URL = 'https://api.github.com'
GH_COMMENT_IDENTIFIER = '<!-- PR-GITHUB-ACTIONS-COMMENT -->'
GH_TOKEN = os.getenv("GH_TOKEN", "")
GH_REPO = os.getenv("GH_REPO", "")
GH_PR_NUMBER = os.getenv("GH_PR_NUMBER", "")
GH_RUN_ID = os.getenv("GH_RUN_ID", "")

HELP_DESCRIPTION = """
Script used to process NixOS configuration diff data. The processed data
is printed to stdout by default and it is possible to post it to a Github comment
in a table format.
"""

HELP_EXAMPLE = """
Example: %(prog)s --diff-folder ./diffs --comment-on-pr
"""

log.basicConfig(
    level=log.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[log.StreamHandler(sys.stdout)],
)

def parse_args():
    parser = ArgumentParser(
        prog="NixOS system diff summary generator.",
        description=HELP_DESCRIPTION,
        epilog=HELP_EXAMPLE,
    )
    parser.add_argument(
        "-d",
        "--diff-folder",
        required=True,
        help="Location of the folder with generated system diffs.",
    )
    parser.add_argument(
        "-c",
        "--comment-on-pr",
        action="store_true",
        help="Flag controlling if to comment on the Github PR, used only in Github Actions.",
    )

    return parser.parse_args()

def http_request(method, url, data=None, retries=3, backoff_factor=1):
    """
    A generic function to perform HTTP requests on Github API.

    :param method: HTTP method (GET, POST, PATCH, etc.)
    :param url: The URL for the request.
    :param data: Optional data to be sent as JSON.
    :param retries: Number of retries for request.
    :param backoff_factor: Number affecting delay between retries.
    :return: Tuple of (response body as JSON, HTTP status code).
    """
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {GH_TOKEN}",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    for attempt in range(1, retries + 1):
        try:
            response = requests.request(method, url, headers=headers, json=data)
            status_code = response.status_code
            body = response.json() if response.text else {}
            if 200 <= status_code < 300:
                return body, status_code
            log.warning(f"Request failed with status {status_code}. Retrying {attempt}/{retries}...")
        except requests.exceptions.RequestException as e:
            log.error(f"HTTP request error on attempt {attempt}/{retries}: {e}")
        except json.JSONDecodeError as e:
            log.error(f"JSON decode error on attempt {attempt}/{retries}: {e}")
        if attempt < retries:
            time.sleep(backoff_factor * attempt)
    log.error(f"All {retries} retries failed for URL: {url}")
    sys.exit(1)

def comment_on_github_pr(summary_table):
    """
    Function to comment on a GitHub PR.

    :param summary_table: String multiline containing summary in table representation.
    """
    comment_body = f"{GH_COMMENT_IDENTIFIER}\n{summary_table}"
    log.info(f"Fetching existing comments from the PR - {GH_PR_NUMBER}")
    url = f"{GH_API_URL}/repos/{GH_REPO}/issues/{GH_PR_NUMBER}/comments"
    comments, status_code = http_request("GET", url)

    if status_code != 200:
        log.error(
            f"Get comments returned status code {status_code}. Response: {comments}"
        )
        sys.exit(1)

    comment_id = None
    for comment in comments:
        if GH_COMMENT_IDENTIFIER in comment.get("body", ""):
            comment_id = comment["id"]
            break

    if comment_id:
        log.info(f"Updating the existing comment with ID: {comment_id}.")
        update_url = f"{GH_API_URL}/repos/{GH_REPO}/issues/comments/{comment_id}"
        data = {"body": comment_body}
        _, status_code = http_request("PATCH", update_url, data)
        if status_code != 200:
            log.error(f"Updating comment returned status code {status_code}.")
        else:
            log.info("Successfully updated comment.")
    else:
        log.info("Creating a new comment.")
        create_url = f"{GH_API_URL}/repos/{GH_REPO}/issues/{GH_PR_NUMBER}/comments"
        data = {"body": comment_body}
        _, status_code = http_request("POST", create_url, data)
        if status_code != 201:
            log.error(f"Creating a comment returned status code {status_code}.")
        else:
            log.info("Successfully created a comment.")

def write_github_workflow_summary(table):
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a") as f:
            f.write(table)
    else:
        log.warning("GITHUB_STEP_SUMMARY environment variable not set")

def parse_combined_diff_file(file_path):
    """Parse the combined diff file to extract both dependency diff and service updates."""
    diff = "NO"
    start = 0
    stop = 0
    restart = 0
    try:
        with open(file_path, "r") as file:
            content = file.readlines()

        diff_exists = next(
            (line.strip() for line in content if "Dependencies diff" in line), None
        )
        if diff_exists:
            diff = "YES"

        def count_services(line, prefix):
            if line.startswith(prefix):
                return len(line.split(":", 1)[-1].strip().split())
            return 0

        start = sum(count_services(line, "Services to start:") for line in content)
        stop = sum(count_services(line, "Services to stop:") for line in content)
        restart = sum(count_services(line, "Services to restart:") for line in content)
    except FileNotFoundError:
        log.error(f"File {file_path} not found.")
        pass

    return diff, start, stop, restart

def get_emoji(count, symbol):
    """Maps counts to emoji."""
    if count == 0:
        return ":white_check_mark: 0"
    else:
        return f":{symbol}: {count}"

def process_folder_data(diff_folder):
    """Extract data from all machine diff files and return structured results."""
    results = []
    folder = Path(diff_folder)

    for diff_file in sorted(folder.glob("*.summary")):
        hostname = diff_file.stem
        diff, start, stop, restart = parse_combined_diff_file(diff_file)
        result = {
            "hostname": hostname,
            "diff": diff,
            "start": start,
            "stop": stop,
            "restart": restart,
            "start_emoji": get_emoji(start, "heavy_plus_sign"),
            "stop_emoji": get_emoji(stop, "warning"),
            "restart_emoji": get_emoji(restart, "red_circle"),
        }
        results.append(result)

    return results

def output_tables(results, diff_folder):
    """Generates two markdown tables:
    - comment_table: clipped for PR comment
    - full_table: full content for GitHub run summary
    """
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    github_run_url = f"https://github.com/{GH_REPO}/actions/runs/{GH_RUN_ID}"
    header = f"## [Fleet Changes]({github_run_url}) (Updated: {current_time})\n\n"
    header += "| Hostname | Start | Stop | Restart | Diff |\n"
    header += "| -------- | ----- | ---- | ------- | ---- |\n"
    comment_rows = [header]
    summary_rows = [header]

    for item in results:
        row = f"| `{item['hostname']}` | {item['start_emoji']} | {item['stop_emoji']} | {item['restart_emoji']} | `{item['diff']}` |\n"
        comment_rows.append(row)
        summary_rows.append(row)

    comment_rows.append("\n<details><summary><h2>Full report</h2></summary>\n")
    summary_rows.append("\n<details><summary><h2>Full report</h2></summary>\n")

    for diff_file in sorted(Path(diff_folder).glob("*.summary")):
        with open(diff_file, "r") as file:
            diff_content = file.read()

        NO_DIFF_LENGTH = 93
        if len(diff_content.strip()) <= NO_DIFF_LENGTH:
            continue

        # Clip for comment version
        comment_diff = diff_content
        # PR comments accept 65536 unicode characters.
        if len(diff_content) >= 4000:
            split_point = diff_content.find("Dependencies diff")
            if split_point != -1:
                comment_diff = diff_content[:split_point].rstrip()
                comment_diff += "\n\nDependencies diff clipped because it was too long. Full diff in the GitHub Actions run summary."

        diff_title = diff_file.stem
        # PR comment
        comment_rows.append(f"<details><summary><h3>{diff_title}</h3></summary>\n")
        comment_rows.append(f"<pre>\n{comment_diff}</pre>\n")
        comment_rows.append("</details>\n")
        # Workflow summary
        summary_rows.append(f"<details><summary><h3>{diff_title}</h3></summary>\n")
        summary_rows.append(f"<pre>\n{diff_content}</pre>\n")
        summary_rows.append("</details>\n")

    comment_rows.append("</details>\n")
    summary_rows.append("</details>\n")

    # Limited PR comment content and full lenght Workflow summary.
    return "".join(comment_rows), "".join(summary_rows)


def output_json(results):
    """Outputs to stdout a json summarizing the data."""
    json_output = []
    for item in results:
        json_output.append(
            {
                "hostname": item["hostname"],
                "diff": item["diff"],
                "services": {
                    "start": item["start"],
                    "stop": item["stop"],
                    "restart": item["restart"],
                },
            }
        )

    json.dump(json_output, sys.stdout, indent=4)

def main():
    args = parse_args()

    results = process_folder_data(args.diff_folder)

    comment_table, full_table = output_tables(results, args.diff_folder)
    output_json(results)

    if os.environ.get('GITHUB_ACTIONS', False):
        write_github_workflow_summary(full_table)

    if args.comment_on_pr:
        comment_on_github_pr(comment_table)

if __name__ == "__main__":
    main()
