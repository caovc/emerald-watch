# Local author-clear replay verification

Custom levels run on fixed 60 Hz simulation ticks. Successful build, upgrade,
sell, wave and ability actions are recorded against simulation ticks; pause and
speed only change wall-clock presentation. The level's canonical full data,
seed, current game-rule source/bytecode and Godot version are bound by hashes.

A win triggers a separate, hidden game world. It starts with the level's actual
starting gold and no towers/enemies, executes the same game methods, rejects
commands that fail their normal legality checks, and runs the real combat tick.
Verification requires actual victory at the exact recorded tick and matching
health, gold, kills, wave, RNG state and tower stats/cooldowns. No replacement
combat model or stored victory boolean is accepted.

The proof is local at `user://author_proof.json`. After a restart, use the
level designer's replay verification button to rerun the saved evidence.
Only a successful verification in the current session grants the verified
badge. Editing the level, changing rules/engine, or modifying the saved proof
invalidates it. A new successful rerun can restore verification for matching
content. Only one saved author proof is retained.

Bounds: 60 simulation minutes, 12,000 commands, 2 MiB proof file. Exceeding a
bound leaves the level playable but unverified. Missing rules source/bytecode
also fails closed. This proves reproducibility under the local game rules;
it is not server-backed author identity or tamper-proof competitive ranking.

Run tests with an isolated user data directory:

    HOME=/tmp/replay-home XDG_DATA_HOME=/tmp/replay-home/data \
      XDG_CONFIG_HOME=/tmp/replay-home/config XDG_CACHE_HOME=/tmp/replay-home/cache \
      godot --headless --path . --script res://tests/author_replay.gd

The test writes and tampers with its isolated local proof file.
