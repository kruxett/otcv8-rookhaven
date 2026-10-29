# v20 full outfit review

New artwork remains unapproved. PixelLab generated the complete base, base + addon1,
and base + both addons jointly, all 36 frames. Complete native Knight/Warmaster
art and masks supplied on the actual generation call; Warrior, Demon Hunter and
Wayfarer complete art/mask reference sets were also extracted and used in preceding
joint attempts. No individual direction was generated separately.

Known issues: helmet crest orientation/shape and changes in underlying garments
across addon tiers remain visible. AI alters opaque garment coverage. These full
worn states are therefore not ready for independent native addon import. Original
fixed native pixels are preserved. User has approved no v20 art.

The AI color-mask attempt retained shading, gray and skin colors. The working mask
normalizes color predictions, uses original native body channels where predictions
are missing, and labels new addon edges from the closest labeled costume pixel in
the same cell. This changes only mask metadata, not the costume art; boundaries
require visual review. User-editable source is editable-v20-complete-outfit.

Passed asset checks: neutral hue-only conversion preserves all AI alpha; protected
native pixels exact in all36 frames; ASE/ORA layer readback and compositing exact;
four tint channels isolated; 288 native SPR tiles roundtrip; DAT/SPR hashes unchanged.
No client/server integration or in-game test was performed for this art proposal.
