-- Campaign Upload Sessions Table
-- Run this in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS campaign_upload_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mr_phone VARCHAR(20) NOT NULL,
  campaign_name VARCHAR(255) NOT NULL,
  image_count INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 minutes')
);

-- Index for fast lookup by phone and status
CREATE INDEX IF NOT EXISTS idx_campaign_sessions_phone_status
ON campaign_upload_sessions(mr_phone, status);

-- Index for expiry cleanup
CREATE INDEX IF NOT EXISTS idx_campaign_sessions_expires
ON campaign_upload_sessions(expires_at) WHERE status = 'active';

-- Optional: Auto-expire old sessions (run periodically or use Supabase Edge Function)
-- UPDATE campaign_upload_sessions
-- SET status = 'expired'
-- WHERE status = 'active' AND expires_at < NOW();
