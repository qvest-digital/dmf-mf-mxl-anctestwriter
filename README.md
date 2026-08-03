# dmf-mf-mxl-anc-testsrc

An ancillary-data test source: writes one RFC 8331 ancillary timecode packet per
grain into an MXL **data** flow (`video/smpte291`).

It exists because nothing else produces data. The DMF demo topology has video
writers and an audio writer, so discrete data grains — their creation, their
cross-node mirroring, and how a consumer presents a flow it cannot play — were
never exercised by anything real.

Booked as a media function: the class lives in
[`dmf-catalog`](https://github.com/qvest-digital/dmf-catalog)
(`functions/mxl-anc-testsrc`), which also carries the chart that deploys it and
pins the image tag a claim provisions.

## What it writes

One ANC packet per grain, framed as SMPTE ST 12-2 Ancillary Time Code — DID/SDID
`0x60/0x60`, `Data_Count` 16 — which is what libmxl's `mxl-data-probe` labels it.
The timecode comes from each grain's own timestamp, so a probe dump can be checked
straight against the wall clock.

MXL stores ancillary data as RFC 8331 **from the Length field on**; libmxl's
`Architecture.md` is explicit that the leading RTP bytes are redundant and are not
stored. So a grain is a 6-byte header followed by ANC packet data. `src/anc_frame.h`
documents the exact word layout.

### The payload is BCD, not ST 12M-2

The user data words carry the time as BCD, one field per word:

```
UDW[0] = hours   UDW[1] = minutes   UDW[2] = seconds   UDW[3] = frames
UDW[4..15] = 0
```

That is deliberately **not** the ST 12M-2 bit layout, which packs a 64-bit
timecode word with DBB1/DBB2 and binary groups across all sixteen words. Nothing
in this ecosystem decodes ATC user data — the probe prints the words raw — so a
layout readable straight off that dump is worth more than an unverifiable
imitation. **Do not point a conformant ATC decoder at this and expect it to read
the time.** If that day comes, replace `anc::build_atc_udw` and keep the framing.

The 10-bit words do carry correct SMPTE 291 parity (b8 even over b0..b7, b9 its
inverse) and a correct checksum, so a reader that checks them sees a valid packet.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `MXL_DOMAIN` | `/run/mxl/domain` | MXL domain root |
| `MXL_FLOW_ID` | `a0d20000-0000-0000-0000-000000000001` | the flow to write |
| `MXL_GRAIN_RATE_NUM` | `30000` | grain rate numerator |
| `MXL_GRAIN_RATE_DEN` | `1001` | grain rate denominator |
| `MXL_ANC_LINE` | `9` | VANC line reported in the packet |
| `MXL_LABEL` | `MXL ANC Test Timecode` | NMOS label |
| `MXL_DESCRIPTION` | see source | NMOS description |

Flow registration is implicit: writing into the domain is enough. The node agent's
fanotify watch publishes the `MxlFlow` CR from the flow definition and renews its
origin Lease.

## Building

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

`libmxl` comes from the `go-mxl-builder` / `go-mxl-runtime` images; the headers
are vendored under `vendor/`. The two halves are pinned to one `GO_MXL_TAG` in the
Dockerfile and must move together — the builder's headers and the runtime's
`libmxl.so` are released as a pair.

```bash
docker build -t dmf-mf-mxl-anc-testsrc:dev .
```

## Tests

`tests/anc_frame_test.cpp` round-trips the framing through **two** parsers: the one
in `src/anc_frame.h` and one transcribed verbatim from libmxl's `mxl-data-probe`.
Holding both to agreement is the point — it means the bytes this writes cannot
drift from what the reference tool reads. It also covers what a malformed grain
looks like: short buffers, a `Length` past the end, a truncated payload.

The suite needs neither libmxl nor a network, so `ctest` runs inside the image
build. A framing regression fails the build instead of surfacing as a confusing
probe dump on a cluster.

## Releasing

Conventional commits drive release-please, producing a `1.0.0-rc.N` train.
Merging the release PR cuts a tag and publishes a release; that published release
is what tags the image. The catalog pins which tag a claim provisions, so a
release is not live anywhere until that pin moves.
