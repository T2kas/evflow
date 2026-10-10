"""Serve the operator / city dashboard on localhost.

    python3 dashboard/serve.py            # live data from GitHub (app-data branch), refreshes every 3 min
    python3 dashboard/serve.py --local    # run export_app.py first and use local app_data/ (works without GitHub)
    python3 dashboard/serve.py --port 8080 --no-open

Only the standard library is used. The map tiles and fonts still need internet.
"""
import argparse
import functools
import http.server
import os
import subprocess
import sys
import webbrowser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--local", action="store_true", help="export app_data/ locally and read it instead of GitHub")
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    if args.local:
        subprocess.run([sys.executable, os.path.join(ROOT, "export_app.py"), "--no-fetch"], check=True)

    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=ROOT)
    handler.log_message = lambda *a: None
    url = f"http://localhost:{args.port}/dashboard/" + ("?src=local" if args.local else "")
    with http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler) as srv:
        print(f"evflow dashboard: {url}  (Ctrl+C sustabdo)")
        if not args.no_open:
            webbrowser.open(url)
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
