# =============================================================================
# NetBox extra Python configuration
# Mounted read-only into all three NetBox containers.
#
# This file extends the default NetBox config. Anything you put here overrides
# the defaults set by environment variables in netbox.env.
# =============================================================================

# ── Login banner ──────────────────────────────────────────────────────────────
BANNER_TOP    = "Desert Fish Network — Internal Use Only"
BANNER_BOTTOM = "Unauthorised access is prohibited."
BANNER_LOGIN  = "Desert Fish Network Source of Truth — Authorised Personnel Only"

# ── Pagination ────────────────────────────────────────────────────────────────
# Show 50 items per page in list views (default is 25).
PAGINATE_COUNT = 50

# ── API pagination ────────────────────────────────────────────────────────────
# Oxidized and Ansible both call the API; raise the max so they get all
# 60 switches in a single request without needing to page.
MAX_PAGE_SIZE = 200

# ── Change logging ─────────────────────────────────────────────────────────────
# Keep a full changelog for every object. This gives you a complete audit trail
# of who changed what in NetBox and when (separate from Oxidized's config diffs).
CHANGELOG_RETENTION = 365   # days

# ── Rack elevation ────────────────────────────────────────────────────────────
RACK_ELEVATION_DEFAULT_UNIT_HEIGHT = 22
RACK_ELEVATION_DEFAULT_UNIT_WIDTH  = 220

# ── Custom fields ─────────────────────────────────────────────────────────────
# Useful custom fields are created via the UI or the netbox_populate playbook.
# Define any site-specific settings here if needed.
