#!/usr/bin/env python3
"""Assert UsernameSystemFactory verify standard-json is Etherscan-replayable.

Requires `forge build` so out/UsernameSystemFactory.sol/UsernameSystemFactory.json exists.
Dumps `forge verify-contract --show-standard-json-input` (the JSON Etherscan would
compile), checks source keys / metadata flags, then recompiles with solc 0.8.30
and compares creation bytecode including nested IPFS CBOR blobs to the artifact.

`--libraries` is passed to match VerifyDeploy, then cleared before solc so the
hashed metadata matches `forge build` (libraries are linked after compile).
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "out" / "UsernameSystemFactory.sol" / "UsernameSystemFactory.json"
CONTRACT_ID = "src/contracts/UsernameSystemFactory.sol:UsernameSystemFactory"
LIB_FLAG = (
    "src/contracts/utils/NostrClaimLink.sol:NostrClaimLink:"
    "0x0000000000000000000000000000000000000001"
)
SOLC_VERSION = "0.8.30"
CBOR_RE = re.compile(r"a2646970667358221220[0-9a-f]{64}", re.IGNORECASE)


def fail(msg: str) -> None:
    print(f"check-factory-metadata: {msg}", file=sys.stderr)
    sys.exit(1)


def load_json_from_stdout(raw: str) -> dict:
    start = raw.find("{")
    if start < 0:
        fail(f"no JSON object in forge output:\n{raw[:500]}")
    return json.loads(raw[start:])


def find_solc() -> Path:
    env = os.environ.get("SOLC")
    if env:
        path = Path(env)
        if path.is_file():
            return path
    version_dir = f"solc-{SOLC_VERSION}"
    candidates = [
        Path.home() / "Library" / "Application Support" / "svm" / SOLC_VERSION / version_dir,
        Path.home() / ".svm" / SOLC_VERSION / version_dir,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    which = subprocess.run(["which", "solc"], capture_output=True, text=True)
    if which.returncode == 0:
        path = Path(which.stdout.strip())
        if path.is_file():
            return path
    fail(
        f"solc {SOLC_VERSION} not found; set SOLC= or install via svm "
        f"(expected ~/Library/Application Support/svm/{SOLC_VERSION}/{version_dir})"
    )
    raise AssertionError("unreachable")


def strip_hex_prefix(value: str) -> str:
    value = value.lower()
    return value[2:] if value.startswith("0x") else value


def dump_standard_json() -> dict:
    cmd = [
        "forge",
        "verify-contract",
        "0x0000000000000000000000000000000000000001",
        CONTRACT_ID,
        "--show-standard-json-input",
        "--libraries",
        LIB_FLAG,
    ]
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if proc.returncode != 0:
        fail(f"forge verify-contract failed:\n{proc.stderr or proc.stdout}")
    return load_json_from_stdout(proc.stdout)


def assert_source_keys(std: dict) -> None:
    sources = std.get("sources") or {}
    if not sources:
        fail("standard-json has no sources")
    bad = [key for key in sources if ".." in key or key.startswith("/") or key.startswith("\\")]
    if bad:
        fail(f"standard-json source keys must be relative with no '..': {bad[:8]}")


def assert_metadata_flags(std: dict, artifact_meta: dict) -> None:
    std_meta = (std.get("settings") or {}).get("metadata") or {}
    if std_meta.get("useLiteralContent") is not True:
        fail(f"verify standard-json useLiteralContent must be true, got {std_meta!r}")
    if std_meta.get("bytecodeHash") != "ipfs":
        fail(f"verify standard-json bytecodeHash must be ipfs, got {std_meta!r}")
    art_meta = (artifact_meta.get("settings") or {}).get("metadata") or {}
    if art_meta.get("useLiteralContent") is not True:
        fail(f"forge build artifact useLiteralContent must be true, got {art_meta!r}")
    if art_meta.get("bytecodeHash") != "ipfs":
        fail(f"forge build artifact bytecodeHash must be ipfs, got {art_meta!r}")


def compile_standard_json(std: dict, solc: Path) -> str:
    compile_input = json.loads(json.dumps(std))
    compile_input.setdefault("settings", {})["libraries"] = {}
    proc = subprocess.run(
        [str(solc), "--standard-json"],
        input=json.dumps(compile_input),
        text=True,
        capture_output=True,
        cwd=ROOT,
    )
    if proc.returncode != 0:
        fail(f"solc failed:\n{proc.stderr or proc.stdout}")
    out = json.loads(proc.stdout)
    errors = [err for err in out.get("errors", []) if err.get("severity") == "error"]
    if errors:
        fail(f"solc errors: {json.dumps(errors[:3], indent=2)}")
    contracts = out.get("contracts", {}).get("src/contracts/UsernameSystemFactory.sol", {})
    factory = contracts.get("UsernameSystemFactory") or {}
    obj = ((factory.get("evm") or {}).get("bytecode") or {}).get("object")
    if not obj:
        fail("solc output missing UsernameSystemFactory bytecode")
    return strip_hex_prefix(obj)


def main() -> None:
    if not ARTIFACT.is_file():
        fail("missing artifact; run `pnpm build` first")

    artifact = json.loads(ARTIFACT.read_text())
    artifact_meta = artifact["metadata"]
    if isinstance(artifact_meta, str):
        artifact_meta = json.loads(artifact_meta)
    artifact_bytecode = strip_hex_prefix(artifact["bytecode"]["object"])

    std = dump_standard_json()
    assert_source_keys(std)
    assert_metadata_flags(std, artifact_meta)

    solc = find_solc()
    compiled = compile_standard_json(std, solc)
    if compiled != artifact_bytecode:
        compiled_cbor = CBOR_RE.findall(compiled)
        artifact_cbor = CBOR_RE.findall(artifact_bytecode)
        fail(
            "creation bytecode (including nested CBOR) does not match artifact\n"
            f"  solc len={len(compiled)} cbor={len(compiled_cbor)}\n"
            f"  art  len={len(artifact_bytecode)} cbor={len(artifact_cbor)}\n"
            f"  solc cbor[:2]={compiled_cbor[:2]}\n"
            f"  art  cbor[:2]={artifact_cbor[:2]}"
        )

    print(
        "check-factory-metadata: ok "
        f"(sources={len(std['sources'])}, bytecode={len(artifact_bytecode)} hex, "
        f"cbor={len(CBOR_RE.findall(artifact_bytecode))})"
    )


if __name__ == "__main__":
    main()
