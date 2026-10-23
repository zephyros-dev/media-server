"""A dedicated user for musicgrabber's rescans and duplicate
checks. Admin, since navidrome only lets admins trigger a scan"""

import shlex

from pyinfra.operations import python

from deploy.application import run
from deploy.application.quadlet import App
from deploy.common.facts import ansible_vars

CLI = "podman exec navidrome-web /app/navidrome"
USER = "musicgrabber"
# Runs `argv` in a terminal and answers each password prompt with the first stdin line,
# like ansible's expect module (the host has python, not `script` or `expect`)
EXPECT_PASSWORD = """
import os, pty, sys
password = sys.stdin.readline().encode()
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
output = b""
while True:
    try:
        chunk = os.read(fd, 1024)
    except OSError:
        break
    if not chunk:
        break
    output += chunk
    if b"password" in output.lower().rsplit(b"\\n", 1)[-1]:
        os.write(fd, password)
        output += b"\\n"
sys.exit(os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1]))
"""


def deploy(app: App):
    app.service()
    python.call(name=f"{app.name}: {USER} user", function=_user)


def _user():
    # The server creates the database schema on startup, so retry until it's there
    _, output = run.retry(
        lambda: run.run(f"{CLI} user list --format csv --nobanner"), retries=30
    )
    # csv columns: user id,username,name,email,admin,...
    users = {
        row[1]: row for line in output.stdout_lines if len(row := line.split(",")) > 4
    }

    if USER not in users:
        # `user create` only reads the password from a terminal, for both prompts (new and
        # confirm). The password goes in on stdin, out of argv
        password = ansible_vars()["navidrome_musicgrabber_password"]
        run.run(
            f"python3 -c {shlex.quote(EXPECT_PASSWORD)}"
            " podman exec -it navidrome-web /app/navidrome user create"
            f" --username {USER} --admin --nobanner",
            stdin=f"{password}\n",
        )
    # For a user created before it was made admin
    elif users[USER][4] == "false":
        run.run(f"{CLI} user edit --user {USER} --set-admin --nobanner")
