# Historical OTSP trial helpers

The Acolyte (OTSP 20/21) trial was rejected and rolled back at the user's request.
These helpers and their screenshots document that earlier trial. The production
shop no longer contains those offers and the native fixtures deliberately depend
on the old trial configuration. Do not run the importer with `--apply` or the
old purchase/render fixtures as current acceptance tests without first adapting
them to a newly approved outfit. Generic shop grant contracts remain covered by
the private fixtures in `tools/quiver-tests/shop-admin-contract.lua`.
