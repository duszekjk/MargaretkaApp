codex conversation [20260722-sync] connect logout and account deletion to Apple lifecycle

Call the authenticated backend when signing out so its access token is revoked,
and add a confirmed account-deletion action that removes the cloud account,
synced records, photos, local API session, and per-account sync bookkeeping.

Keep local prayer data and original photos when deleting the cloud account, as
the confirmation explains. Scope revisions, last-success dates, and uploaded
photo tracking by account to prevent one Apple user from contaminating another,
while migrating the earlier single-account keys.
