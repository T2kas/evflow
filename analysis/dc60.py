import runpy, sys
from datetime import timedelta
sys.argv=[sys.argv[0], sys.argv[1]]
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path(sys.argv[0].replace("dc60.py","analyze.py"), run_name="x")
good, st, pclass, LT = g["good"], g["st"], g["pclass"], g["LT"]
for name, ss in [("LT", good), ("Vilnius", [s for s in good if st[s["cid"]]["city"].strip().lower().startswith("vilni")])]:
    dc = [s for s in ss if pclass(s).startswith("DC")]
    o = [s for s in dc if s["dur"] > 60]
    ex = sum(s["dur"]-60 for s in o)/60
    print(name, "DC sessions", len(dc), ">60min", len(o), round(len(o)/len(dc),3), "excess beyond 60min h", round(ex,1), "per day", round(ex/3.08,1))
    pub_ac = [s for s in ss if pclass(s)=="AC" and not st[s["cid"]]["restriction"]]
    o2 = [s for s in pub_ac if s["dur"] > 8*60]
    print(name, "public AC", len(pub_ac), ">8h", len(o2), round(len(o2)/len(pub_ac),3))
