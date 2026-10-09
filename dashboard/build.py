"""Bake app_data/city_stats.json + Vilnius stations into dashboard/index.html.

    python export_app.py && python dashboard/build.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "..", "app_data")

with open(os.path.join(APP, "city_stats.json"), encoding="utf-8") as f:
    stats = json.load(f)
with open(os.path.join(APP, "stations.json"), encoding="utf-8") as f:
    stations = json.load(f)["stations"]

vil = [{
    "id": s["id"], "name": s["name"], "operator": s["operator"], "lat": s["lat"], "lon": s["lon"],
    "blocking_hours": s["history"]["blocking_hours"], "overstay_share": s["history"]["overstay_share"],
    "broken": s["counts"]["broken"],
} for s in stations if s["city"] == "Vilnius"]

data = json.dumps({"stats": stats, "vil": vil}, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
with open(os.path.join(HERE, "template.html"), encoding="utf-8") as f:
    page = f.read().replace("/*__DATA__*/", data)
with open(os.path.join(HERE, "index.html"), "w", encoding="utf-8") as f:
    f.write(page)
print(f"dashboard/index.html: {len(page) // 1024} KB, {len(vil)} Vilnius stations")
