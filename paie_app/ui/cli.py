from pathlib import Path
import sys, argparse, inspect

# --- make "paie_app" importable so "from core..." works ---
APP = Path(__file__).resolve().parents[1]   # .../paie_app
sys.path.insert(0, str(APP))

from core.router import Router               # now resolves
SETTINGS = APP / "config" / "settings.yaml"

def main():
    p = argparse.ArgumentParser(prog="cli.py")
    p.add_argument("--user",     default="default", help="user id / profile owner")
    p.add_argument("--model",    default=None,      help="override model (optional)")
    p.add_argument("--profile",  default=None,      help="profile name (e.g., friendly/formal)")
    p.add_argument("--template", default=None,      help="template key (e.g., academic/concise/bug_report)")
    p.add_argument("--kind",     required=True,     choices=["user_story","use_case","test_case","summary"])
    p.add_argument("prompt",     nargs="+")
    args   = p.parse_args()
    prompt = " ".join(args.prompt)

    r = Router(str(SETTINGS))

    # Build a superset of possible kwargs, then filter to what Router.run supports.
    params = dict(
        kind=args.kind,
        prompt=prompt,
        user=args.user,
        model=args.model,
        profile_name=args.profile,
        template_name=args.template
    )

    try:
        allowed = set(inspect.signature(r.run).parameters.keys())
        safe    = {k:v for k,v in params.items() if k in allowed and v is not None}
        out     = r.run(**safe) if safe else r.run(args.kind, prompt)
    except Exception:
        # Fallback for very strict signatures
        out = r.run(args.kind, prompt)

    text = out.get("text","") if isinstance(out, dict) else (str(out) if out is not None else "")
    print(text)

if __name__ == "__main__":
    raise SystemExit(main())
