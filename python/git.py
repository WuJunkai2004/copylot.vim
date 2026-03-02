import subprocess


def gitLog(n: int = 5) -> str:
    try:
        return subprocess.check_output(["git", "log", f"-n {n}"]).decode("utf-8")
    except subprocess.CalledProcessError as e:
        return f"An error occurred: {e}"


def gitDiff(cached: bool = True) -> str:
    try:
        if cached:
            return subprocess.check_output(["git", "diff", "--cached"]).decode("utf-8")
        else:
            return subprocess.check_output(["git", "diff"]).decode("utf-8")
    except subprocess.CalledProcessError as e:
        return f"An error occurred: {e}"
