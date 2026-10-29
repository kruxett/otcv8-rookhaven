# Harbor Envoy — fresh Citizen-based costume proposal

Current deliverable: `male/editable-v2/`. Open `harbor-envoy-male.aseprite` or `.ora`, or edit `base.png` / `mask.png`. Its README explains native frame placement and four player-color channels.

The user requested a clean standard starter-body template and a completely different costume style after the Nobleman-derived design became too busy. This new proposal uses actual Citizen male 128 source frames, extracted directly from current DAT/SPR: all four directions, idle and both native walk phases, addon zero. The costume is a simple tailored seafarer jacket with broad contrast collar/cuffs, dark trousers and one belt clasp. No previous Nobleman/Rookwarden image was supplied as a costume reference.

`source/reference/native-poses.json` identifies the source sprite IDs, input hashes and fixed translation. `male/source/v1-citizen/` preserves the original PixelLab image and two-pixel cleaned version. `male/source/v2-recolorable/` contains guarded material edits, source/mask validation and the shared export regression. The first inpainting submit exceeded the tool's 2000-character description limit and was rejected without a job; the valid generation is a12a5b1d-7307-4ca4-8db1-8cbb6e26ad33 (6 generations). Subsequent workbench operations are exact free pixel edits. A detached generated two-pixel fragment was removed from the source and both layers; final validation has no new isolated components.

The exporter now accepts optional reference prefix/directory, filename stem and default color IDs. Its previous Rookwarden default export remains pixel/ASE-identical, with identical ORA entries. All 96 new BASE/MASK tiles survive a legacy SPR encode/decode roundtrip. No gameplay tests or build are applicable to this graphics-only proposal. The previews are software renders; native game rendering remains for approved integration.

Old Rookwarden/Nobleman assets are preserved. No game assets, outfit grants, shop offers or deployments were changed. The male design is awaiting review; a separate female Citizen proposal follows after style approval.
