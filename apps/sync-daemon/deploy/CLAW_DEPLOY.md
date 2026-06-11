# sync-daemon on the Hetzner box

The same daemon code runs on the user's laptop *and* a Hetzner box, both
syncing to the same Firestore subtree. Each instance tags its writes with
`updated_by` = `BRAIN_SYNC_NODE_ID` and ignores Firestore changes it produced
itself, so a change on either node propagates to the other.

Hostname / IP for the specific deployment lives in `personal.md` (gitignored)
at the project root.

## Layout on the box

```
/opt/sync-daemon/           the code (rsync'd from laptop, excludes node_modules)
/opt/Brain/                  the markdown tree (bootstrapped from laptop)
/etc/brain-sync-claw/.env    secrets + config (chmod 600, root:root)
/etc/systemd/system/brain-sync-claw.service
```

## Environment

`/etc/brain-sync-claw/.env`:

```
BRAIN_SYNC_USER_ID=<your Firebase UID>
BRAIN_SYNC_NODE_ID=hetzner
BRAIN_PATH=/opt/Brain
GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

`GOOGLE_SERVICE_ACCOUNT_JSON` is the full JSON inlined on one line (same
service account the laptop daemon uses, exported via Firebase Console
-> Project Settings -> Service accounts -> Generate new private key).
