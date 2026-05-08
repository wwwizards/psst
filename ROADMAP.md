# psst Query Enhancement Roadmap

**Current state (v0.4.0):** Fuzzy pattern matching with implicit OR logic. Works great for simple cases (`psst h` → hostpool tests) but limited for complex scenarios.

---

## v0.5.0: SQL-Like Query Syntax

**Timeline:** Post AVD v0.8.0 (when test count > 50)

### Problem Statement
Current fuzzy matching treats all arguments as OR conditions:
```powershell
psst 01 smoke    # Matches "01" OR "smoke" → too broad
psst cost eastus # Matches "cost" OR "eastus" → includes all cost tests + all eastus tests
```

For growing test suites (100+ tests across phases), need precise control over selection logic.

### Proposed Syntax

#### Explicit Boolean Logic
```powershell
# AND operator (require all conditions)
psst -Query "01 and smoke"              # Phase-01 smoke tests only
psst -q "hostpool and not smoke"        # Phase-03 integration tests (exclude smoke)

# OR operator (match any condition)
psst -q "01 or 03"                      # Phase-01 and Phase-03 tests
psst -q "(foundation or hostpool) and smoke"  # Multi-phase smoke runs

# Complex expressions with parentheses
psst -q "(cost and eastus2) or (sku and westus2)"  # Region-specific resource tests
psst -q "integration and (01 or 03 or 08)"         # Integration tests for specific phases
```

#### Keyword Matching (Current Behavior as Fallback)
```powershell
psst h              # Fuzzy match "h" → hostpool.Tests.ps1 (unchanged)
psst smoke          # All smoke tests (simple case, no -Query needed)
psst 01             # All Phase-01 tests (simple case)
```

#### Regex Support (Advanced)
```powershell
psst -q "phase:0[1-3]"              # Phases 01-03 using regex
psst -q "name:/.*integration.*/"    # All tests with "integration" in name
psst -q "tag:Smoke and not tag:Slow"  # Tag-based filtering (requires Pester tag support)
```

#### Date/Time Filters (v0.6.0+)
```powershell
psst -q "modified:today"            # Tests changed today
psst -q "created:>2025-11-01"       # Tests added since Nov 1
psst -q "duration:<5s"              # Fast tests only (requires telemetry data)
```

---

## v0.6.0: Saved Queries & Aliases

**Timeline:** AVD v0.9.x (Mature test suites with 100+ tests)

### Features
- **Named queries:** Save complex expressions for reuse
- **Aliases:** Shortcuts for common patterns
- **Query history:** Recall previous queries with autocomplete

### Usage
```powershell
# Define saved query
psst --save "precommit" -q "smoke and not integration"

# Run saved query
psst --run precommit

# Define alias
psst --alias "quick" "smoke and duration:<10s"

# Use alias
psst quick

# Query history
psst --history         # Show last 20 queries
psst --recall 3        # Re-run 3rd query from history
```

### Configuration File
`~/.psst/queries.json`:
```json
{
  "saved": {
    "precommit": "smoke and not integration",
    "postdeploy": "integration and (03 or 08)",
    "regression": "not tag:Known-Issue"
  },
  "aliases": {
    "quick": "smoke and duration:<10s",
    "slow": "duration:>60s",
    "failing": "result:Failed"
  },
  "history": [
    {"timestamp": "2025-11-05T14:32:10Z", "query": "01 and smoke"},
    {"timestamp": "2025-11-05T14:35:22Z", "query": "hostpool and not smoke"}
  ]
}
```

---

## v0.7.0: Test Result Caching & Smart Re-Run

**Timeline:** AVD v1.0+ (CI/CD integration)

### Features
- **Result cache:** Remember pass/fail state from previous runs
- **Smart re-run:** Only execute tests that failed or changed since last run
- **Baseline comparison:** Detect new failures (regressions)

### Usage
```powershell
# Run all tests, cache results
psst --cache

# Re-run only failures from last run
psst --failed

# Re-run tests affected by file changes (git diff)
psst --changed

# Compare against baseline (detect regressions)
psst --baseline main --compare feature-branch
```

### Use Cases
- **CI/CD optimization:** Skip passing tests on incremental commits (10x faster builds)
- **Regression detection:** Alert on new failures introduced by PR
- **Flaky test tracking:** Identify tests with intermittent failures

---

## v0.8.0: Parallel Execution & Load Balancing

**Timeline:** Post v1.0 (when test duration > 5 minutes)

### Features
- **Parallel execution:** Run independent tests concurrently (multi-core)
- **Load balancing:** Distribute long-running tests across sessions
- **Progress reporting:** Real-time updates with ETA

### Usage
```powershell
# Run tests in parallel (default: CPU core count)
psst -Parallel

# Limit parallelism
psst -Parallel -MaxJobs 4

# Smart scheduling (run slow tests first)
psst -Parallel -Schedule Smart

# Distributed execution (future: remote workers)
psst -Parallel -Workers @('worker1', 'worker2', 'worker3')
```

### Technical Challenges
- **Pester limitations:** Current version runs tests serially within `Invoke-Pester`
- **State isolation:** Tests must not share mutable state (Azure resources, files)
- **Result aggregation:** Merge results from parallel sessions

---

## v0.9.0: Integration with `psstel` Telemetry

**Timeline:** Synchronized with psstel v0.3.0

### Features
- **Automatic logging:** Every `psst` run writes telemetry event
- **Historical trends:** Show pass rate, duration, flakiness over time
- **Smart test selection:** Prioritize tests likely to fail (ML-based)

### Usage
```powershell
# Run tests with telemetry (automatic)
psst smoke
# → Logs to psstel: EventType=Test, Source=Manual, Result=Success/Failed

# View test history
psst --stats hostpool
# → Show last 30 days: pass rate 94%, avg duration 12.3s, 2 flaky tests

# Predict failure likelihood
psst --predict
# → "hostpool.Tests.ps1: 68% failure risk (last 3 runs failed)"
```

---

## v1.0.0: Enterprise Test Orchestration

**Timeline:** Multiple clients in production

### Features
- **Multi-project support:** Run tests across multiple AVD projects
- **Tenant isolation:** Separate test contexts for Phoenix, NYC, future clients
- **Dashboard integration:** Real-time test progress in web UI
- **Notification hooks:** Slack/Teams alerts on test failures
- **Policy enforcement:** Require 100% smoke pass before deploy

### Architecture
```
psst CLI → psstel telemetry → Azure Storage → Dashboard
    ↓                              ↓              ↓
  Pester                     Event Hub      Grafana Panels
    ↓                              ↓              ↓
 Test Results            Azure Functions   Slack Alerts
```

---

## Implementation Notes

### Phase 1: Query Parser (v0.5.0)
1. Tokenize input string (split on whitespace, preserve quoted strings)
2. Build expression tree (precedence: parentheses > AND > OR > NOT)
3. Evaluate predicates against test metadata (name, path, tags, phase)
4. Map to Pester `-Tag` or custom filter logic

### Phase 2: Tag Standardization (v0.5.0 prerequisite)
Require all tests to use consistent Pester tags:
```powershell
Describe 'Foundation smoke' -Tag 'Smoke','Phase01','Foundation' {
  # tests
}

Describe 'HostPool integration' -Tag 'Integration','Phase03','HostPool','Azure' {
  # tests
}
```

Query examples:
```powershell
psst -q "tag:Smoke and tag:Phase01"         # → Run foundation smoke tests
psst -q "tag:Integration and not tag:Azure" # → Run integration tests without Azure deps
```

### Phase 3: Performance Optimization (v0.7.0+)
- Cache test discovery results (don't re-scan file tree every run)
- Index test metadata (SQLite or JSON file)
- Incremental updates (only re-index changed files)

---

## Decision Points

**When to implement query syntax?**
- Test count exceeds 50 across multiple phases
- Need precise control (AND/NOT logic) for CI/CD workflows
- Developers complain about fuzzy matching being too broad

**When to implement parallel execution?**
- Test suite duration exceeds 5 minutes
- Have multiple independent test files (no shared state)
- CI/CD pipeline time becomes bottleneck

**When to integrate with psstel?**
- Need historical test metrics (flakiness, duration trends)
- Want predictive test selection (run high-risk tests first)
- Building multi-client operations with centralized telemetry

---

## Compatibility Promise

- **Backward compatible:** Simple fuzzy matching remains default behavior
- **Opt-in syntax:** `-Query` parameter required for SQL-like expressions
- **No breaking changes:** Existing scripts continue working unchanged
- **Gradual adoption:** Teams can migrate at their own pace
