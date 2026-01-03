# Incidents Table - SQL Update Query

Run this query in your **Supabase SQL Editor** to update the incidents table with all required columns.

---

## Full ALTER TABLE Query

```sql
-- =====================================================
-- COMPREHENSIVE ALTER TABLE FOR INCIDENTS
-- Safe to run - uses IF NOT EXISTS for all additions
-- =====================================================

-- Add all required columns (safe - won't fail if column exists)
DO $$
BEGIN
    -- Core identification
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'short_id') THEN
        ALTER TABLE incidents ADD COLUMN short_id VARCHAR(8);
    END IF;

    -- MR reference (if not exists)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'mr_id') THEN
        ALTER TABLE incidents ADD COLUMN mr_id UUID REFERENCES staff(id);
    END IF;

    -- Incident details
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'incident_type') THEN
        ALTER TABLE incidents ADD COLUMN incident_type VARCHAR(50);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'incident_description') THEN
        ALTER TABLE incidents ADD COLUMN incident_description TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'detailed_description') THEN
        ALTER TABLE incidents ADD COLUMN detailed_description TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'reason') THEN
        ALTER TABLE incidents ADD COLUMN reason TEXT;
    END IF;

    -- Status tracking
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'status') THEN
        ALTER TABLE incidents ADD COLUMN status VARCHAR(20) DEFAULT 'open';
    END IF;

    -- Resolution fields
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'resolution_notes') THEN
        ALTER TABLE incidents ADD COLUMN resolution_notes TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'resolved_by') THEN
        ALTER TABLE incidents ADD COLUMN resolved_by UUID REFERENCES staff(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'resolved_at') THEN
        ALTER TABLE incidents ADD COLUMN resolved_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Timestamps
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'created_at') THEN
        ALTER TABLE incidents ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'incidents' AND column_name = 'updated_at') THEN
        ALTER TABLE incidents ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Generate short_id for existing rows that don't have one
UPDATE incidents
SET short_id = substr(id::text, 1, 8)
WHERE short_id IS NULL AND id IS NOT NULL;

-- Add unique constraint on short_id if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'incidents_short_id_key') THEN
        ALTER TABLE incidents ADD CONSTRAINT incidents_short_id_key UNIQUE (short_id);
    END IF;
EXCEPTION WHEN others THEN
    NULL; -- Ignore if constraint already exists
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_incidents_mr_id ON incidents(mr_id);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_short_id ON incidents(short_id);
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON incidents(created_at);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_incidents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_incidents_updated_at ON incidents;
CREATE TRIGGER trigger_incidents_updated_at
    BEFORE UPDATE ON incidents
    FOR EACH ROW
    EXECUTE FUNCTION update_incidents_updated_at();

-- Auto-generate short_id on insert
CREATE OR REPLACE FUNCTION generate_incident_short_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.short_id IS NULL THEN
        NEW.short_id := substr(NEW.id::text, 1, 8);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_incident_short_id ON incidents;
CREATE TRIGGER trigger_incident_short_id
    BEFORE INSERT ON incidents
    FOR EACH ROW
    EXECUTE FUNCTION generate_incident_short_id();
```

---

## Table Schema After Update

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `short_id` | VARCHAR(8) | Short ID for easy reference (e.g., "abc12345") |
| `mr_id` | UUID | Foreign key to staff table |
| `incident_type` | VARCHAR(50) | Type: stock_empty, doctor_unavailable, etc. |
| `incident_description` | TEXT | Brief description of the incident |
| `detailed_description` | TEXT | Extended details (added later) |
| `reason` | TEXT | Root cause of the issue |
| `status` | VARCHAR(20) | open, in_progress, resolved |
| `resolution_notes` | TEXT | How the issue was resolved |
| `resolved_by` | UUID | HO user who resolved it |
| `created_at` | TIMESTAMP | When incident was created |
| `updated_at` | TIMESTAMP | Auto-updated on changes |
| `resolved_at` | TIMESTAMP | When incident was resolved |

---

## Valid Incident Types

- `stock_empty` - Product/sample stock unavailable
- `doctor_unavailable` - Doctor not at clinic
- `clinic_closed` - Clinic was closed
- `transport_issue` - Vehicle breakdown
- `weather_issue` - Bad weather conditions
- `medical_leave` - MR health issues
- `documentation_missing` - Required docs unavailable
- `other` - Any other issue
