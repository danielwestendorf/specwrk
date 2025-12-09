# Changelog

## Unreleased  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.19.2...main)  

## v0.19.2 — 2025-12-09  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.19.1...v0.19.2)  
- Optimize msgpack usage by using one packer/unpacker — [#180](https://github.com/danielwestendorf/specwrk/pull/180) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Standard style to v3.4 — [#179](https://github.com/danielwestendorf/specwrk/pull/179) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Add msgpack to the docker server — [#178](https://github.com/danielwestendorf/specwrk/pull/178) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.19.1 — 2025-12-08  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.19.0...v0.19.1)  
- Add missing require for serializer in base adapter — [#177](https://github.com/danielwestendorf/specwrk/pull/177) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.19.0 — 2025-12-08  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.18.0...v0.19.0)  
- Add support for configured serializer, adding msgpack — [#176](https://github.com/danielwestendorf/specwrk/pull/176) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.18.0 — 2025-12-07  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.17.1...v0.18.0)  
- Spawn workers with `spawn` instead of `fork` — [#174](https://github.com/danielwestendorf/specwrk/pull/174) by [@danielwestendorf](https://github.com/danielwestendorf)  
- If pending is empty, return before acquiring lock — [#173](https://github.com/danielwestendorf/specwrk/pull/173) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Fix typo resulting in wrong group by — [#166](https://github.com/danielwestendorf/specwrk/pull/166) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.17.1 — 2025-12-06  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.17.0...v0.17.1)  
- Version bump only (no functional changes) — [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.17.0 — 2025-12-06  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.16.3...v0.17.0)  
- Add bucket store — [#170](https://github.com/danielwestendorf/specwrk/pull/170) by [@danielwestendorf](https://github.com/danielwestendorf)  
- s/Bucket/BucketStore — [#171](https://github.com/danielwestendorf/specwrk/pull/171) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Bucket at seed — [#172](https://github.com/danielwestendorf/specwrk/pull/172) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Split Store classes into their own files — [#169](https://github.com/danielwestendorf/specwrk/pull/169) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Fix worker failing to flush on worker exit — [#167](https://github.com/danielwestendorf/specwrk/pull/167) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Typo — [#168](https://github.com/danielwestendorf/specwrk/pull/168) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.16.3 — 2025-12-01  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.16.2...v0.16.3)  
- Disable locks on heartbeat and health endpoints — [#163](https://github.com/danielwestendorf/specwrk/pull/163) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Add specwrk worker info to logger — [#164](https://github.com/danielwestendorf/specwrk/pull/164) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Ignore Agents.md — [#165](https://github.com/danielwestendorf/specwrk/pull/165) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.16.2 — 2025-10-23  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.16.1...v0.16.2)  
- exit(1) from seed process when example size is zero — [#158](https://github.com/danielwestendorf/specwrk/pull/158) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.16.1 — 2025-10-03  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.16.0...v0.16.1)  
- Ensure next_examples are always cleared after execution — [#156](https://github.com/danielwestendorf/specwrk/pull/156) by [@danielwestendorf](https://github.com/danielwestendorf)  
- More frequent heartbeats — [#154](https://github.com/danielwestendorf/specwrk/pull/154) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Ensure mutex is held when a lock is expected — [#153](https://github.com/danielwestendorf/specwrk/pull/153) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.16.0 — 2025-10-02  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.10...v0.16.0)  
- Support retry of all client requests, configurable count — [#151](https://github.com/danielwestendorf/specwrk/pull/151) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Expire workers from worker heartbeats — [#149](https://github.com/danielwestendorf/specwrk/pull/149) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Fix a few minor typos in README — [#147](https://github.com/danielwestendorf/specwrk/pull/147) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Run flake test if the srv uri is localhost — [#146](https://github.com/danielwestendorf/specwrk/pull/146) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.10 — 2025-08-28  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.9...v0.15.10)  
- Handle default path for start and seed better — [#144](https://github.com/danielwestendorf/specwrk/pull/144) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Mention Redis storage adapter — [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.9 — 2025-08-28  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.8...v0.15.9)  
- Support lock skipping for read-only endpoints — [#139](https://github.com/danielwestendorf/specwrk/pull/139) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Fix typo in README — [#137](https://github.com/danielwestendorf/specwrk/pull/137) by [@willnet](https://github.com/willnet)  
- Support an array of arguments when seeding/starting — [#141](https://github.com/danielwestendorf/specwrk/pull/141) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Load examples from processing before global lock — [#142](https://github.com/danielwestendorf/specwrk/pull/142) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.8 — 2025-08-27  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.7...v0.15.8)  
- Friendly helper message when Redis adapter is not available — [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.7 — 2025-08-26  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.6...v0.15.7)  
- Change request locking from global to per-`run_id` — [#135](https://github.com/danielwestendorf/specwrk/pull/135) by [@danielwestendorf](https://github.com/danielwestendorf)  
- `rspec-core` is a runtime dependency (not `rspec`) — [#128](https://github.com/danielwestendorf/specwrk/pull/128) by [@bquorning](https://github.com/bquorning)  
- README typo fix — [#126](https://github.com/danielwestendorf/specwrk/pull/126) by [@brett-anderson](https://github.com/brett-anderson)  

## v0.15.6 — 2025-08-26  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.5...v0.15.6)  
- Test `Store.adapter_klass` — [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.5 — 2025-08-26  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.4...v0.15.5)  
- Add support for Redis store adapters — [#133](https://github.com/danielwestendorf/specwrk/pull/133) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Remove support for Ruby 3.1.0 — [@danielwestendorf](https://github.com/danielwestendorf)  
- Remove `gem-release` from dev dependencies — [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.4 — 2025-08-23  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.3...v0.15.4)  
- Split web endpoints into separate files for easier comprehension — [#129](https://github.com/danielwestendorf/specwrk/pull/129) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Write the title sequence as watch loops run — [#131](https://github.com/danielwestendorf/specwrk/pull/131) by [@danielwestendorf](https://github.com/danielwestendorf) (fixes [#130](https://github.com/danielwestendorf/specwrk/issues/130))  

## v0.15.3 — 2025-08-22  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.2...v0.15.3)  
- Clear filter-manager inclusions/exclusions when listing examples — [#122](https://github.com/danielwestendorf/specwrk/pull/122) by [@danielwestendorf](https://github.com/danielwestendorf) (fixes [#121](https://github.com/danielwestendorf/specwrk/issues/121))  
- Smarter completion-threshold calculation; make runs resumable — [#124](https://github.com/danielwestendorf/specwrk/pull/124) by [@danielwestendorf](https://github.com/danielwestendorf) (fixes [#121](https://github.com/danielwestendorf/specwrk/issues/121))  

## v0.15.2 — 2025-08-15  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.1...v0.15.2)  
- Fix bug where Ruby objects were being written to NDJSON files instead of JSON — [#119](https://github.com/danielwestendorf/specwrk/pull/119) by [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.1 — 2025-08-14  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.15.0...v0.15.1)  
- Add `watch` command to split spec files across processes as they change — [#117](https://github.com/danielwestendorf/specwrk/pull/117) by [@danielwestendorf](https://github.com/danielwestendorf)  
- README formatting tweaks — [@danielwestendorf](https://github.com/danielwestendorf)  

## v0.15.0 — 2025-08-08  
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.14.1...v0.15.0)  
- Per-worker NDJSON output when `--output` is specified — [#113](https://github.com/danielwestendorf/specwrk/pull/113) by [@danielwestendorf](https://github.com/danielwestendorf) (fixes [#10](https://github.com/danielwestendorf/specwrk/issues/10))  
- Print re-run commands for failures — [#114](https://github.com/danielwestendorf/specwrk/pull/114) by [@danielwestendorf](https://github.com/danielwestendorf) (fixes [#7](https://github.com/danielwestendorf/specwrk/issues/7))  
- Show number of examples that did not execute; make runs resumable — [#115](https://github.com/danielwestendorf/specwrk/pull/115) by [@danielwestendorf](https://github.com/danielwestendorf)  
- Report flake counts and re-run commands — [#116](https://github.com/danielwestendorf/specwrk/pull/116) by [@danielwestendorf](https://github.com/danielwestendorf) (fixes [#112](https://github.com/danielwestendorf/specwrk/issues/112))  

## v0.14.1 — 2025-08-07
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.14.0...v0.14.1)
- Fix CLI typo — @danielwestendorf

## v0.14.0 — 2025-08-07
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.13.1...v0.14.0)
- Add support for example retries (`--max-retries` for `start` and `seed`) — [#111](https://github.com/danielwestendorf/specwrk/pull/111) (addresses [#96](https://github.com/danielwestendorf/specwrk/issues/96)) by @danielwestendorf

## v0.13.1 — 2025-08-07
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.13.0...v0.13.1)
- Require `securerandom` in the FileAdapter to ensure availability — @danielwestendorf

## v0.13.0 — 2025-08-07
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.12.0...v0.13.0)
- Avoid multi-process tempfile conflicts by adding a UUID to tempfile names — [#108](https://github.com/danielwestendorf/specwrk/pull/108) (fixes [#107](https://github.com/danielwestendorf/specwrk/issues/107)) by @danielwestendorf
- Remove deprecated `complete` endpoint — [#109](https://github.com/danielwestendorf/specwrk/pull/109) (fixes [#95](https://github.com/danielwestendorf/specwrk/issues/95)) by @danielwestendorf
- Track worker success metrics (succeeded/pending/failed) and use them to instruct worker exit behavior — [#110](https://github.com/danielwestendorf/specwrk/pull/110) (fixes [#97](https://github.com/danielwestendorf/specwrk/issues/97)) by @danielwestendorf

## v0.12.0 — 2025-08-06
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.11.1...v0.12.0)
- Don’t return a body for `HEAD` requests in auth middleware — refs [#102](https://github.com/danielwestendorf/specwrk/issues/102) — @danielwestendorf
- Filter `specwrk` from backtraces — @danielwestendorf
- Move store order tracking to the only store class that needs it (performance improvement) — [#105](https://github.com/danielwestendorf/specwrk/pull/105) by @danielwestendorf
- Humanize seconds output — [#106](https://github.com/danielwestendorf/specwrk/pull/106) (fixes [#11](https://github.com/danielwestendorf/specwrk/issues/11)) by @danielwestendorf

## v0.11.1 — 2025-08-05
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.11.0...v0.11.1)
- Avoid doing work in `before_lock` for `complete` and `pop` endpoints — [#104](https://github.com/danielwestendorf/specwrk/pull/104) (fixes [#103](https://github.com/danielwestendorf/specwrk/issues/103)) by @danielwestendorf

## v0.10.2 — 2025-08-01
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.10.1...v0.10.2)
- Add `complete_and_pop` endpoint to reduce HTTP requests ~50% — [#88](https://github.com/danielwestendorf/specwrk/pull/88) by @danielwestendorf
- File-per-example file store — [#87](https://github.com/danielwestendorf/specwrk/pull/87) by @danielwestendorf
- Remove thread safety (follow-up to thread pool changes) — [#89](https://github.com/danielwestendorf/specwrk/pull/89) by @danielwestendorf
- Fix thread pool start — [#90](https://github.com/danielwestendorf/specwrk/pull/90) by @danielwestendorf

## v0.10.1 — 2025-08-01
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.10.0...v0.10.1)
- Internal cleanups and versioning adjustments for the 0.10.x line

## v0.10.0 — 2025-08-01
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.9.1...v0.10.0)
- Prep for 0.10 baseline (no PRs explicitly tied beyond those in 0.10.1/0.10.2)

## v0.9.1 — 2025-08-01
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.9.0...v0.9.1)
- Minor fixes and tag adjustments

## v0.9.0 — 2025-07-30
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.8.0...v0.9.0)
- File-per-example store groundwork — see [#87](https://github.com/danielwestendorf/specwrk/pull/87) by @danielwestendorf

## v0.8.0 — 2025-07-22
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.7.1...v0.8.0)
- Revert datastore and related adjustments — [#86](https://github.com/danielwestendorf/specwrk/pull/86) by @danielwestendorf
- Just return response if no `run_id` header — [#85](https://github.com/danielwestendorf/specwrk/pull/85) by @danielwestendorf
- On `INT`, if RSpec is defined set `wants_to_quit = true` — [#84](https://github.com/danielwestendorf/specwrk/pull/84) by @danielwestendorf
- Datastore for queues — [#83](https://github.com/danielwestendorf/specwrk/pull/83) by @danielwestendorf

## v0.7.1 — 2025-07-22
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.7.0...v0.7.1)
- Minor tag-only bump

## v0.7.0 — 2025-07-22
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.6.3...v0.7.0)
- Only exit 1 when no examples processed and run not completed — [#82](https://github.com/danielwestendorf/specwrk/pull/82) by @danielwestendorf
- Switch from Puma to Pitchfork — [#79](https://github.com/danielwestendorf/specwrk/pull/79) by @danielwestendorf
- Dump all runs as unique — [#78](https://github.com/danielwestendorf/specwrk/pull/78) by @danielwestendorf

## v0.6.3 — 2025-07-17
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.6.2...v0.6.3)
- Reap queues based on staleness of workers — [#76](https://github.com/danielwestendorf/specwrk/pull/76) by @danielwestendorf
- Track worker `first_seen_at` / `last_seen_at` — [#75](https://github.com/danielwestendorf/specwrk/pull/75) by @danielwestendorf
- Unique default ID when no `SPECWRK_ID` provided — [#74](https://github.com/danielwestendorf/specwrk/pull/74) by @danielwestendorf
- Send `X-Specwrk-Id` and `User-Agent` headers — [#71](https://github.com/danielwestendorf/specwrk/pull/71) by @danielwestendorf

## v0.6.2 — 2025-07-17
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.6.1...v0.6.2)
- Tag-only bump

## v0.6.1 — 2025-07-17
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.6.0...v0.6.1)
- Tag-only bump

## v0.6.0 — 2025-07-17
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.5.0...v0.6.0)
- Output success message when seeding succeeds — [#67](https://github.com/danielwestendorf/specwrk/pull/67) by @danielwestendorf

## v0.5.0 — 2025-07-15
[Compare](https://github.com/danielwestendorf/specwrk/compare/v0.4.11...v0.5.0)
- Support specifying if subsequent seeds should be ignored for a run — [#37](https://github.com/danielwestendorf/specwrk/pull/37) by @danielwestendorf
- Make number of seed waits configurable — [#35](https://github.com/danielwestendorf/specwrk/pull/35) by @danielwestendorf
- Worker wait for seeding — [#32](https://github.com/danielwestendorf/specwrk/pull/32) by @danielwestendorf
- Track if the worker has processed *any* examples — [#31](https://github.com/danielwestendorf/specwrk/pull/31) by @danielwestendorf


## v0.4.11

- Move logic out of CLI methods ([#64](https://github.com/danielwestendorf/specwrk/issues/64)) by @danielwestendorf  
- Add thruster in front of puma ([#65](https://github.com/danielwestendorf/specwrk/issues/65)) by @danielwestendorf  
- Revise heartbeats logic ([#66](https://github.com/danielwestendorf/specwrk/issues/66)) by @danielwestendorf  

## v0.4.9

- Remove single-run env var (it was not what I wanted) by @danielwestendorf  

## v0.4.8

- Fix `config.ru` by @danielwestendorf  

## v0.4.7

- Switch to Puma for the Docker image (#59) by @danielwestendorf  

## v0.4.6

- Nil env var that will prevent start command from completing ([#56](https://github.com/danielwestendorf/specwrk/issues/56)) by @danielwestendorf  
- Better handling of seed failing ([#57](https://github.com/danielwestendorf/specwrk/issues/57)) by @danielwestendorf  
- Silence health logging ([#58](https://github.com/danielwestendorf/specwrk/issues/58)) by @danielwestendorf  
- Add missing CCI caching of `report.json` ([#55](https://github.com/danielwestendorf/specwrk/issues/55)) by @danielwestendorf  
- Add CircleCI examples ([#50](https://github.com/danielwestendorf/specwrk/issues/50)) by @danielwestendorf  
- Better GHA Examples ([#49](https://github.com/danielwestendorf/specwrk/issues/49)) by @danielwestendorf  
- Skip key lookup and rely on the result of `Hash#delete` instead by @danielwestendorf  

## v0.4.5

- Set ENV var when generating seed examples [#47](https://github.com/danielwestendorf/specwrk/issues/47). by @danielwestendorf 
## v0.4.4

- Don’t dump the completed queue if it’s empty [#45](https://github.com/danielwestendorf/specwrk/issues/45). by @danielwestendorf
- Move single-run CLI option to only be an option for the `serve` command [#41](https://github.com/danielwestendorf/specwrk/issues/41). by @danielwestendorf
- Don’t complete examples which are not in the processing queue [#44](https://github.com/danielwestendorf/specwrk/issues/44). by @danielwestendorf

## v0.4.3

- Fix CLI’s `--uri` option description. by @danielwestendorf
- Add an unauthenticated `/health` endpoint to the server [#40](https://github.com/danielwestendorf/specwrk/issues/40). by @danielwestendorf
- Add support excluding server paths from authentication [#39](https://github.com/danielwestendorf/specwrk/issues/39). by @danielwestendorf

## v0.4.2

- Add specwrk variations to CI [#38](https://github.com/danielwestendorf/specwrk/issues/38). by @danielwestendorf
- Support specifying if subsequent seeds should be ignored for a run [#37](https://github.com/danielwestendorf/specwrk/issues/37). by @danielwestendorf

## v0.4.1

- Make the number of seed waits configurable [#35](https://github.com/danielwestendorf/specwrk/issues/35). by @danielwestendorf

## v0.4.0

- Worker wait for seeding [#32](https://github.com/danielwestendorf/specwrk/issues/32). by @danielwestendorf
- Track if the worker has processed *any* examples [#31](https://github.com/danielwestendorf/specwrk/issues/31). by @danielwestendorf

## v0.3.0

- Assign `Specwrk.net_http` to `Net::HTTP` before WebMock can mock it [#22](https://github.com/danielwestendorf/specwrk/issues/22). by @danielwestendorf
- Worker PIDs representative exit status [#20](https://github.com/danielwestendorf/specwrk/issues/20). by @danielwestendorf
- Track an individual worker’s failures [#19](https://github.com/danielwestendorf/specwrk/issues/19). by @danielwestendorf
- Default localhost server URI is not SSL. by @danielwestendorf
- Handle SSL-protected srv endpoints [#18](https://github.com/danielwestendorf/specwrk/issues/18). by @danielwestendorf

## v0.2.0

- Tag v0.2.0 by @danielwestendorf
