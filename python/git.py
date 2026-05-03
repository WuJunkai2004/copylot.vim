import subprocess


def gitLog(n: int = 5) -> str:
    try:
        return subprocess.check_output(["git", "log", "-n", str(n)]).decode("utf-8", errors="replace")
    except subprocess.CalledProcessError as e:
        return f"An error occurred: {e}"


def gitDiff(cached: bool = True) -> str:
    try:
        if cached:
            return subprocess.check_output(["git", "diff", "--cached"]).decode("utf-8", errors="replace")
        else:
            return subprocess.check_output(["git", "diff"]).decode("utf-8", errors="replace")
    except subprocess.CalledProcessError as e:
        return f"An error occurred: {e}"
