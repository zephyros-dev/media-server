import json

from pyinfra import host

from deploy.common.data import REPO
from deploy.common.facts import cue_facts

facts = cue_facts()

# `--data cue_fact_debug=true` dumps the cue output, e.g. to diff it against ansible's
if host.data.get("cue_fact_debug"):
    debug_dir = REPO / "cue/tmp"
    debug_dir.mkdir(exist_ok=True)
    (debug_dir / f"cue-{host.name}.json").write_text(
        json.dumps(facts, indent=2, sort_keys=True)
    )
