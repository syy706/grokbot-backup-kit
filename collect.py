#!/usr/bin/env python3
"""Stage allowlisted Grok Bot box data into a dir. Usage: collect.py STAGE_DIR [--list]"""
import os, re, sys, shutil, sqlite3, json, subprocess, time
# ======================= CONFIG (edit here) =======================
# Roots. Override with env BACKUP_HOME / BACKUP_WORKSPACE.
HOME=os.environ.get("BACKUP_HOME","/home/box"); AD=f"{HOME}/agent-data"
WORKSPACE=os.environ.get("BACKUP_WORKSPACE","/workspace")
# Size limits (bytes): workspace files / config files.
MAX_WS=1_000_000; MAX_CFG=2_000_000
# ALLOWLIST: top-level agent-data JSON files and directories to back up.
AD_FILES=["settings.json","deleted-agents.json","sand-feature-flag-overrides.json"]
AD_DIRS=["workflows","plugin-skills"]
PLUGIN_CFG_NAMES=("plugin.json","mcp.json","installed.json","config.json")
WS_EXT={".sh",".py",".js",".ts",".mjs",".json",".md",".txt",".yaml",".yml",".toml",".html",".css",".ipynb",".cfg",".ini"}
# EXCLUDES: exact file names that are never copied (secrets / runtime state).
DENY_NAMES={"box-secrets.json","host-secrets.json","gateway.json","chrome-cookie-seed.json",
 "source-map.json","teach-queue-key.json","sand-statsig-bootstrap.json"}
# Add your own exclusions via env BACKUP_EXTRA_EXCLUDE_DIRS="dir1,dir2".
# ===================================================================
STAGE=sys.argv[1] if len(sys.argv)>1 else sys.exit("usage: collect.py STAGE_DIR [--list]")
LIST="--list" in sys.argv
DENY_RE=re.compile(r"(token|secret|cookie|credential|passw|\bkey|_key|-key|\.key$|\.pem$|\.env|id_rsa|\.lock$|^\.sand-)",re.I)
DENY_DIRS={".git","node_modules","venv",".venv","__pycache__",".cache","cache","assets","attachments",
 "tools","site-packages",".ssh","gh","models","checkpoints","frames","out","dist","build"}
DENY_DIRS|={x.strip() for x in os.environ.get("BACKUP_EXTRA_EXCLUDE_DIRS","").split(",") if x.strip()}
files=[]
def ok(name): return name not in DENY_NAMES and not DENY_RE.search(name)
def add(src, rel):
    if not ok(os.path.basename(src)): return
    files.append((src, rel))
def walk(root, relroot, exts=None, maxsz=MAX_CFG):
    for d, dirs, fs in os.walk(root):
        dirs[:] = [x for x in dirs if x not in DENY_DIRS and not x.startswith(".venv") and x!="agent-tools" and ok(x)]
        for f in fs:
            p=os.path.join(d,f)
            if os.path.islink(p) or not os.path.isfile(p): continue
            if f.endswith((".min.js",".min.css")): continue
            if exts and os.path.splitext(f)[1].lower() not in exts: continue
            if os.path.getsize(p)>maxsz: continue
            add(p, os.path.join(relroot, os.path.relpath(p, root)))
# agent-data
for f in AD_FILES:
    if os.path.exists(f"{AD}/{f}"): add(f"{AD}/{f}", f"agent-data/{f}")
for d in AD_DIRS: walk(f"{AD}/{d}",f"agent-data/{d}")
# plugin configs: only plugin.json/mcp.json (cache contents re-download)
for d,_,fs in os.walk(f"{AD}/plugins"):
    for f in fs:
        if f in PLUGIN_CFG_NAMES:
            p=os.path.join(d,f); add(p,"agent-data/"+os.path.relpath(p,AD))
dbs=[]
for a in (sorted(os.listdir(f"{AD}/agents")) if os.path.isdir(f"{AD}/agents") else []):
    ap=f"{AD}/agents/{a}"
    if not os.path.isdir(ap): continue
    for f in os.listdir(ap):
        p=f"{ap}/{f}"
        if f.endswith(".json") and os.path.isfile(p): add(p,f"agent-data/agents/{a}/{f}")
        elif f=="store.db" and os.path.getsize(p)<5_000_000: dbs.append((p,f"agent-data/agents/{a}/store.db"))
# workspace small text work
walk(WORKSPACE,"workspace",exts=WS_EXT,maxsz=MAX_WS)
if LIST:
    tot=0
    for s,r in files+dbs: sz=os.path.getsize(s); tot+=sz; print(f"{sz:>9} {r}")
    print(f"TOTAL {len(files)+len(dbs)} files, {tot/1024:.1f} KiB"); sys.exit()
data=os.path.join(STAGE,"data")
shutil.rmtree(data,ignore_errors=True)
for s,r in files:
    dst=os.path.join(data,r); os.makedirs(os.path.dirname(dst),exist_ok=True); shutil.copy2(s,dst)
for s,r in dbs:  # consistent sqlite snapshot
    dst=os.path.join(data,r); os.makedirs(os.path.dirname(dst),exist_ok=True)
    src=sqlite3.connect(f"file:{s}?mode=ro",uri=True); out=sqlite3.connect(dst); src.backup(out); out.close(); src.close()
# manifest
def run(c):
    try: return subprocess.run(c,shell=True,capture_output=True,text=True,timeout=120).stdout
    except Exception as e: return f"ERR {e}"
m=os.path.join(STAGE,"manifest"); os.makedirs(m,exist_ok=True)
for name,cmd in {"pip-user.txt":"pip freeze --user 2>/dev/null","pip-all.txt":"pip freeze 2>/dev/null",
 "npm-global.txt":"npm -g ls --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -r -n1 basename",
 "apt-manual.txt":"apt-mark showmanual 2>/dev/null","local-bin.txt":"ls ~/.local/bin 2>/dev/null"}.items():
    open(os.path.join(m,name),"w").write(run(cmd))
json.dump({"generated_at":time.strftime("%Y-%m-%dT%H:%M:%S%z"),"file_count":len(files)+len(dbs),
 "note":"Memory and routines live server-side and survive box resets; not included."},open(os.path.join(m,"info.json"),"w"),indent=2)
