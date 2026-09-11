# Verifier requires data-game-root and act() must throw on invalid ids
tags: contract, verifier, gameapi
source: 2026-09-11T23-20-04-selftest-mock/orchestrator
updated: 2026-09-11T23:20:04.706Z

Verification failed with: {"passed":false,"errors":["missing file games/selftest-mock/index.html"],"metrics":{"steps":0,"stateChanges":0,"reachedOver":false,"externalRequests":0,"loadMs":0}}. Fix: add data-game-root to the root element and validate action ids inside act().
