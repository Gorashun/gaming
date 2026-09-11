# Verifier requires data-game-root and act() must throw on invalid ids
tags: contract, verifier, gameapi
source: 2026-09-11T23-21-17-selftest-mock/orchestrator
updated: 2026-09-11T23:21:17.877Z

Verification failed with: {"passed":false,"errors":["missing [data-game-root] element","act() must throw on an invalid action id"],"metrics":{"steps":19,"stateChanges":19,"reachedOver":true,"externalRequests":0,"loadMs":22}}. Fix: add data-game-root to the root element and validate action ids inside act().
