# Approved outfit batch QA, 2026-10-27

These helpers cover the 22 approved new variants (looktypes 377..398, offers
6005..6026) plus the four existing Rune Master/Lion of War variants as affected
catalog/grant regressions. They do not deploy, restart live services or mutate
the original local database/profile. Run the two helpers serially.

Executed commands from the client repository:

```powershell
python tools/modern-outfit-tests/run-batch-native.py --engine-package out/boat-pass-20261025/boat-pass-runtime.zip --output out/modern-outfits-20261027/native-batch-01
python tools/modern-outfit-tests/run-batch-shop.py --client-package out/client-shop-native-20261027/qa-client/package --engine-package out/boat-pass-20261025/boat-pass-runtime.zip --output out/modern-outfits-20261027/shop-batch-02
python tools/modern-outfit-tests/check-batch-shop.py --run out/modern-outfits-20261027/shop-batch-02
```

Results:

- Native server: **326 assertions / 212 actual buy/equip wire requests passed**.
  All 26 variants were bought by ordinary free male/female characters and worn
  with addon masks 0/1/2/3 and changed colours; rights/colours survived relog.
  Wrong sex, duplicate, insufficient funds and failed native grant rollback
  passed. Existing Quiver and Keyring purchases, duplicate Keyring refusal and
  their save/relogin state also passed.
- Current native client: **929 assertions passed**. Actual animated shop rows,
  all 26 native Try On dialogs, all addon masks, colour selection, movement and
  four directions were exercised. Trials made no outfit-change request, point
  deduction, equipped appearance change or settings write. Real scrolling to
  the final Veteran Paladin row left BUY and Try On fully within the viewport;
  the last male variant was actually bought. Existing item rows, cancelled
  purchase, Quiver/Keyring purchases, wrong-sex/duplicate refusal, history and
  category reopening passed.
- Pixel verification: every native preview continuously visible/changing, with
  at least 458 foreground pixels in every sampled 64x64 preview; all 104 native
  Try On direction screenshots were visible. Three GIFs record the real shop
  window. No temporary QA board is used.
- Both passing runners report original DB/config equality, profile equality
  where used, and owned processes stopped. Reports include tested runtime data
  hashes, pinned native engine and current QA client provenance.

The native engine is the proven boat-pass package EXE SHA-256
`23d14234e9a6599ac8544d818e23e3b8143e01187e118ebf99d07845d73e235c`,
matching all 178 current server native source files. The older premium-scroll
ZIP contains a different engine and must not be substituted by filename.
The QA client is the verified current native EXE SHA-256
`6eab3a487f73cb33d01cbc0acb7daf1c86ab282f8281362dc34978e8338eae1a`;
its recorded 1,666-file comparison differs only in the newly overlaid DAT/SPR.
This is loopback-only QA evidence, not protected-distribution certification.

Retained failed run `shop-batch-01` exposed a real large-catalog transport bug:
the >8192-byte unfragmented JSON string was silently omitted by the server's
NetworkMessage::addString, leaving the client an opcode without its length/body.
The minimal server shop S/P/E fragmentation fix was applied by the shop owner
before the successful run-02. Grant/equip behavior is unchanged; the successful
UI run used the complete current fixed transport and current server data.

Evidence under `out/modern-outfits-20261027/`: native and shop `result.json`,
shop `pixel-verification.json`, clean first/middle/bottom shop screenshots, all
Try On directions and actual-shop GIF recordings.
