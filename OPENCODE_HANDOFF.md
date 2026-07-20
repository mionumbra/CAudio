# CAudio OpenCode Handoff

## Start A New Session

1. The global GameMaker ResourceTool MCP is already registered in:

   `~/.config/opencode/opencode.json`

   OpenCode DEBUG logging confirms that this machine currently resolves it to:

   `D:\Users\Mionumbra\.config\opencode\opencode.json`

   Merge this entry into the existing configuration rather than replacing unrelated fields:

   ```json
   {
     "$schema": "https://opencode.ai/config.json",
     "mcp": {
       "gamemaker": {
         "type": "local",
         "command": [
           "gm-cli.cmd",
           "resourcetool",
           "mcp"
         ],
         "enabled": true
       }
     }
   }
   ```

2. The configuration is global and intentionally does not bind a specific `.yyp`. Fully quit and restart OpenCode when changing it because MCP configuration is not hot-reloaded.

3. Start OpenCode from the project root:

   ```powershell
   Set-Location "D:\Users\Mionumbra\Documents\GameMaker-LTS\Projects\CAudio"
   opencode
   ```

4. In the new session, send:

   ```text
    Read OPENCODE_HANDOFF.md and continue the CAudio optimization work end-to-end. First verify the GameMaker ResourceTool MCP with gamemaker_status and report the actual tools used. Follow all handoff constraints, preserve existing worktree changes, build and run tests with gm-cli, and do not stop after analysis when implementation is feasible.
   ```

If the MCP is unavailable, verify:

```powershell
Get-Command gm-cli.cmd
gm-cli --version
```

The expected gm-cli version is `2.2.0`.

Current verified MCP state:

- `opencode mcp list` reports `gamemaker connected` using `gm-cli.cmd resourcetool mcp`.
- MCP calls work in-session. `gamemaker_status` loaded this project successfully.
- Actual tools include `gamemaker_status`, `gamemaker_resource_list`, `gamemaker_resource_info`, `gamemaker_object_event_list`, `gamemaker_room_item_list`, and the other `gamemaker_*` tools exposed by the server.
- `gamemaker_object_event_list NAME=Object` successfully listed all current object events.
- `gamemaker_resource_list TYPE=...` accepts one singular resource type per call, such as `object`, `room`, `script`, or `includedfile`; do not pass a comma-separated list.

## Project

Path:

`D:\Users\Mionumbra\Documents\GameMaker-LTS\Projects\CAudio`

CAudio is a pure GML audio loading, decoding, and streaming library:

- No native extension.
- Do not use extgen.
- WAV and pure-GML FLAC decoding are implemented.
- The implementation uses buffers, binary files, `audio_create_buffer_sound`, and `audio_create_play_queue`.
- GameMaker project metadata reports IDE `2026.0.0.16`.
- Global `gm-cli` is version `2.2.0`.

Relevant skills:

- `gml-language-core`
- `gml-audio`
- `gml-data-files`
- `gml-objects-instances`
- `gamemaker-cli`
- Load `gml-structs-methods` when changing structs or API design.
- Load `gml-variables-scope` when changing ownership or variable lifetime.

## Tool Policy

- Prefer the registered GameMaker ResourceTool MCP for project resources, object events, room relationships, and resource changes.
- It is acceptable and expected for gm-cli, ResourceTool MCP, ResourceTool eval/script, and other GameMaker tools to modify or save `.yy`, `.yyp`, `.gml`, and related project files.
- Do not avoid an effective gm-cli or MCP workflow merely because the tool may save the project.
- After tool operations, inspect Git status and diff to distinguish new work from existing changes.
- Preserve unrelated user changes. Do not revert, overwrite, or delete them.
- The worktree is already dirty, and `main` is six commits behind `origin/main`.
- Do not pull, reset, checkout, stash, commit, or push unless explicitly requested.
- Use `apply_patch` for manual edits. Tool-generated or formatter-generated changes may be retained normally.
- Read only the necessary GML hot-path sections rather than repeatedly dumping whole files.
- Carry work through implementation, build, Runner verification, and diff review.

## Core Files

- `scripts/caudio_create/caudio_create.gml`: public API and format dispatch.
- `scripts/caudio_wav/caudio_wav.gml`: WAV parsing, buffer sounds, and disk streaming.
- `scripts/caudio_flac/caudio_flac.gml`: FLAC metadata, frames, subframes, Rice residuals, LPC, CRC, and streaming decode.
- `objects/Object/Create_0.gml`: deterministic Runner test initialization and assertions.
- `objects/Object/Step_0.gml`: deterministic WAV/FLAC lifecycle test state machine.
- `objects/Object/Other_74.gml`: Audio Playback async event.
- `objects/Object/Other_11.gml`: test-only extra fill event.
- `objects/Object/Draw_0.gml`: playback status display.
- `objects/Object/CleanUp_0.gml`: idempotent CAudio resource release.
- `objects/obj_example_full_load/*`: complete-file WAV loading example.
- `objects/obj_example_stream/*`: incremental FLAC streaming example.
- `rooms/rm_example_full_load`: full-load example room.
- `rooms/rm_example_stream`: streaming example room.

## Public API

Keep these interfaces compatible:

```gml
caudio_create_sound(path)
caudio_create_stream(path)
caudio_play(handle, priority = 0, loop = false)
caudio_free(handle)
caudio_stream_fill(stream)
caudio_stream_prime(stream, min_queued)
caudio_stream_pump(stream, min_queued, max_fills)
caudio_stream_on_async(stream, async_load, min_queued)
caudio_stream_is_playable(stream)
caudio_stream_seek(stream, seconds)
caudio_stream_set_loop(stream, loop)
caudio_stream_get_position(stream)
caudio_stream_free(stream)
```

Handle fields:

- `kind`: `"wav"`, `"flac"`, or `"ogg"`
- `mode`: `"buffer"` or `"stream"`

## Completed Optimization Work

### Format Dispatch

In `scripts/caudio_create/caudio_create.gml`:

- Format probing now performs one 12-byte buffer load instead of two 4-byte loads.
- `caudio_stream_pump` only attempts underrun restart when that pump call actually queued new audio.
- Pump checks `audio_exists` before querying playback state, avoiding invalid sound-instance warnings during delayed callbacks.
- Ogg Vorbis probing validates the first Ogg packet's Vorbis signature instead of accepting every `OggS` container.
- OGG uses a native GameMaker stream handle. Queue refill APIs are explicit no-ops; shared play, seek, position, looping, and idempotent cleanup remain available.
- OGG buffer creation is explicitly unsupported and returns `-1`.
- `caudio_stream_is_playable` exposes native OGG readiness. It refreshes duration after an asynchronously loaded stream becomes playable; OGG play and seek return `-1` while not ready, and position safely returns zero.

### WAV

In `scripts/caudio_wav/caudio_wav.gml`:

- A failed `audio_create_buffer_sound` deletes its audio buffer and returns `-1`.
- A failed `audio_create_play_queue` returns `-1`.
- The `fmt` chunk parser loads at most the 40 bytes it needs instead of allocating the file-declared chunk size.
- An Audio Playback async callback refills at most one queue buffer; remaining work is left to the budgeted pump.
- PCM24, PCM32, and IEEE float32 mono/stereo input is converted through one shared signed-16-bit conversion path for both buffer sounds and streams.
- WAV rejects data chunks that are not aligned to complete sample frames, clamps negative seek to zero, and can resume refill when looping is enabled after a clean EOF.
- Full-buffer and concatenated streaming PCM output pass deterministic FFmpeg-reference MD5 checks, including WAVEFORMATEXTENSIBLE with 24 valid bits in a 32-bit container.

### FLAC

In `scripts/caudio_flac/caudio_flac.gml`:

- Full-load mode reads the FLAC file once instead of probing and then reloading it.
- Constant and verbatim subframes no longer allocate an unused residual array.
- `CAudioBitReader.seek` and `skipBits` have an in-window fast path that avoids buffer destruction, recreation, and disk reloads within the current 256 KB window.
- FLAC buffer sounds now include `kind: "flac"` and `mode: "buffer"`.
- Loop streaming has a no-progress guard so empty or damaged input cannot loop forever inside one fill call.
- An Audio Playback async callback refills at most one queue buffer.
- Metadata blocks are bounded by the physical file size, known-length full decodes reject incomplete sample counts, and streams verify frame CRCs and expose `failed` after corruption or premature EOF.
- Metadata-only, first-frame-boundary truncation, and payload corruption rejection tests pass for buffer and streaming paths.
- Windowed frame CRC ranges now use the active 256 KB buffer when fully resident and only reload a temporary range when a frame crosses the window. On the local VM benchmark, one 24-frame fill improved from 555.88 ms and 48 CRC file loads to 234.96 ms and zero CRC file loads; clean YYC measured 45.43 ms and zero CRC file loads.
- Full decode already writes known-length FLAC directly into its final fixed buffer. Unknown-total-samples FLAC now resizes a fixed output buffer as needed instead of decoding to a grow buffer and copying the complete PCM output into a second fixed buffer; a generated totalSamples=0 fixture verifies decode-to-EOF PCM MD5. GameMaker rejects `buffer_grow` in `audio_create_buffer_sound`, so retaining the grow buffer directly is not valid.
- Unknown-total FLAC streams learn total samples and duration at the first clean physical EOF. FLAC seek target probing is transactional and restores reader/live queue state on decode or replacement-queue failure.

### Runner Test And Cleanup

In `objects/Object/Create_0.gml`, `Step_0.gml`, `Other_74.gml`, and `CleanUp_0.gml`:

- The previous interactive demo is now a deterministic state-machine test.
- It tests `IF = Infinity.wav`, `test.flac`, and `边境之城的童谣.flac` in sequence.
- Each case checks format dispatch, stream handles, queue creation, priming, playback, seek, looping, delayed stop callbacks, underrun recovery, queue release, and idempotent cleanup.
- Assertions log `[CAudioTest] PASS/FAIL`; the final result logs failures and calls `game_end()`.
- Audio Playback callbacks perform callback accounting and at most one refill. Step owns the normal pump budget.
- WAV and FLAC queue callbacks require both the current queue ID and current buffer membership. Retired buffers remain grouped by queue generation and stale or unknown callbacks cannot delete or refill the current generation.
- WAV and FLAC free explicitly stop and clear `playId`, matching OGG handle cleanup state.
- A Cleanup event calls `caudio_free` and clears `_audio`, covering room end, instance destruction, and game exit.

## Verification

The project compiled successfully before optimization and after each optimization/test pass using:

```powershell
gm-cli compile "CAudio.yyp" --target=windows --runtime=vm
```

The final compile completed successfully and generated `CAudio.win`.

Automated Runner verification also completed successfully using:

```powershell
gm-cli run "CAudio.yyp" --target=windows --runtime=vm
```

The Runner tested all three included audio files, logged `[CAudioTest] RESULT PASS failures=0`, called `game_end()`, and `gm-cli` reported `Game exited`. The final run had no invalid sound-instance or empty play-queue warnings.

After adding OGG playable-state handling, Windows VM compile and the complete Runner suite passed again. The OGG test verifies ready state, deferred duration availability, playback, seek, position, native looping, released state, and idempotent cleanup. The representative FLAC CRC fill still reported 48 window hits and zero fallback file loads.

After adding queue-generation ownership, Windows VM compile and the complete Runner suite passed. A deterministic synthetic stale-callback test verifies that seek advances generation, replacement queue ownership is distinct while retiring the old queue, an old callback cannot delete a current buffer, and the retired buffer is released by its matching callback. The existing 12-seek FLAC delayed-callback stress test also remains green.

After removing the unknown-total FLAC final PCM copy, Windows VM compile and the complete Runner suite passed. The generated totalSamples=0 fixture decoded 8000 samples through physical EOF and matched PCM MD5 `2b7f0e2a29dde8278db61fa710358cf4`. An attempted direct `buffer_grow` handoff was correctly rejected by the Runner, so the final implementation uses a resizable `buffer_fixed` throughout.

The latest correctness pass adds malformed WAV frame-alignment rejection, negative WAV seek clamping, short-stream loop recovery after a non-looping prime reaches EOF, unknown-total FLAC stream duration discovery, explicit WAV/FLAC `playId` reset, and transactional FLAC seek rollback. A corrupt-target seek test confirms that reader position and the live queue remain unchanged on failure.

Queue release ownership was measured on the Windows VM Runner. Deleting a queued buffer immediately after `audio_free_play_queue` can fail fatally with `Cannot delete buffer, it's in use by 1 others`; therefore the attempted immediate-reclamation change was reverted. Seek retirement remains callback-driven and passes stale-callback/generation tests. Free now transfers outstanding queue ownership to a persistent callback registry, which reclaims each buffer only after its Runner callback and remains alive after Cleanup discards the stream struct.

YYC now also compiles and passes the complete Runner suite. `gm-options.json` persistently selects `D:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat`; this instance provides the required `v142` compiler and uses the D-drive Windows SDK. If incremental output is stale, delete only `.gmcache/build-gms2-windows-YYC` and rerun with the normal cache. Do not switch `--cache-dir`, because that downloads another GameMaker runtime.

The latest release pass adds the persistent retired-queue registry, routes registry reclamation through the public `caudio_stream_on_async` API, initializes WAV stream `done` before first fill, learns exact unknown-total FLAC duration without an epsilon, and normalizes WAV/FLAC loop positions to source sample indices. Natural short-stream loop tests verify position within one source sample and observe an actual wrap. Test logs use `string_format` for position values because direct string conversion shows only two decimal places.

The final Windows VM release gate cleared only `.gmcache/build-gms2-windows-VM`, retained the shared runtime cache, and passed with `[CAudioTest] RESULT PASS failures=0` followed by `Game exited`. The formatted boundary values were WAV `position=0.039875 duration=0.100000` and FLAC `position=0.135875 duration=0.250000`. This exposed and fixed WAV duration integer division; the parser now forces real division. The run reported zero FLAC CRC fallback file loads and no invalid buffer, invalid queue, or queue-ownership fatal errors.

Two standalone examples were added with ResourceTool MCP. `rm_example_full_load` uses `obj_example_full_load` and fully loads `IF = Infinity.wav`, selected from `Downloads`. `rm_example_stream` uses `obj_example_stream` and incrementally streams `边境之城的童谣.flac`, selected from `Music`. Both songs already existed as Included Files, so no duplicate audio was copied. The examples provide pause, restart, seek, loop, room-switch, and cleanup controls; both rooms forward Audio Playback callbacks so registry reclamation survives room transitions. Current Room Order is `rm_example_stream`, `rm_example_full_load`, then deterministic test `Room`.

Initial hands-on example testing found duplicate entries in each example room's `instanceCreationOrder`, left behind when the first MCP-created objects were deleted and recreated. This ran Create twice and then produced an uninitialized `stream` error from the stale creation entry. Both rooms now contain exactly one creation-order entry and one layer instance. Streaming position also remained within the current queue buffer because `playBaseSeconds` was not advanced after callbacks and several sample-to-seconds divisions used integer arithmetic. WAV and FLAC callbacks now advance the base from exact `queueStarts`/`queueSamples`, and all stream sample-to-seconds paths force real division. Direct checks confirmed the full-load WAV plays and advances position, and the FLAC stream maintains three queued buffers while position advances across buffer callbacks. The complete deterministic VM suite still passes afterward.

gm-cli reports that `local_settings.json` cannot be loaded, but compilation still succeeds. This is not currently a blocker.

Not yet verified:

- Long-running seek, loop, and resource-lifetime behavior beyond the short deterministic lifecycle test.
- Delayed callbacks arriving after queue destruction under heavier timing stress.
- Long-duration registry behavior under unusually delayed or missing Runner callbacks.

## Next Priorities

1. Verify MCP with `gamemaker_status`, then use singular-type resource queries as needed.
2. Keep the project desktop-focused; browser targets are intentionally unsupported because core synchronous file APIs are unavailable there.
3. Inspect only the relevant optimization diff and preserve all existing changes.
4. Measure FLAC decode allocations and timing before deeper optimization.

When stale compiled code is suspected, remove only the affected target build directory before running:

```powershell
Remove-Item -LiteralPath ".gmcache\build-gms2-windows-VM" -Recurse -Force
Remove-Item -LiteralPath ".gmcache\build-gms2-windows-YYC" -Recurse -Force
```

Do not pass a new `--cache-dir` for this purpose. It changes the entire gm-cli cache root and causes tools and the GameMaker runtime to be downloaded again.

Do not implement audio queue buffer pooling. Windows VM measurement proved outstanding queued buffers can remain owned after `audio_free_play_queue`; immediate deletion is unsafe.

## Known Correctness Work

- Loop position is normalized to source sample indices and tested across natural WAV and FLAC short-stream boundaries.
- `scripts/int32` and `scripts/uint32` have no current call sites and allocate a buffer per call. Confirm whether they are public compatibility helpers before changing or removing them.

## Worktree Notes

- Many tracked and untracked changes predate this optimization pass and belong to the user.
- `git diff --check` reports existing trailing whitespace in modified GML files. Do not create a large formatting-only diff just to remove it.
- The MCP is now connected and was used successfully for project status and object-event inspection. One combined `resource_list` query failed because `TYPE` accepts one singular type; it did not change project resources.
- Current MCP inspection confirms `Object` has Create, Draw, Audio Playback, User 1, Alarm 0, Step, and Cleanup events.
- ResourceTool eval and MCP may perform normal project save flows. No separate unexpected resource change was identified.
- Compilation and the short Runner lifecycle test do not prove FLAC PCM correctness or long-running audio queue lifetime correctness.

## First Response Expected

The next agent should begin by calling `gamemaker_status` and briefly reporting that the `gamemaker` ResourceTool MCP is available, including the actual `gamemaker_*` tools it used. It should note that the deterministic lifecycle Runner already passes, choose the next measured/correctness-backed optimization, and proceed through implementation, VM compile, Runner execution, and diff review rather than stopping at a plan.
