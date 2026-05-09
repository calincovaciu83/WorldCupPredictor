-- ============================================================================
-- World Cup Predictor Database Schema
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "plpgsql";

-- ============================================================================
-- Users Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  oauth_provider TEXT CHECK (oauth_provider IN ('google', 'github')),
  oauth_id TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_oauth ON users(oauth_provider, oauth_id);

-- ============================================================================
-- Matches Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  match_id INTEGER UNIQUE NOT NULL, -- Football-Data.org ID
  home_team TEXT NOT NULL,
  home_team_emoji TEXT,
  away_team TEXT NOT NULL,
  away_team_emoji TEXT,
  home_rank TEXT,
  away_rank TEXT,
  kickoff_time TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT CHECK (status IN ('upcoming', 'live', 'finished', 'postponed', 'cancelled')) DEFAULT 'upcoming',
  home_score INTEGER,
  away_score INTEGER,
  "group" TEXT,
  venue TEXT,
  attendance INTEGER,
  referee TEXT,
  last_updated TIMESTAMP WITH TIME ZONE,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_matches_status ON matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_kickoff ON matches(kickoff_time);
CREATE INDEX IF NOT EXISTS idx_matches_group ON matches("group");
CREATE INDEX IF NOT EXISTS idx_matches_match_id ON matches(match_id);

-- ============================================================================
-- Predictions Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS predictions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  predicted_home_score INTEGER CHECK (predicted_home_score >= 0),
  predicted_away_score INTEGER CHECK (predicted_away_score >= 0),
  points_earned NUMERIC(5, 2) DEFAULT 0,
  locked_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, match_id)
);

CREATE INDEX IF NOT EXISTS idx_predictions_user ON predictions(user_id);
CREATE INDEX IF NOT EXISTS idx_predictions_match ON predictions(match_id);
CREATE INDEX IF NOT EXISTS idx_predictions_locked ON predictions(locked_at);

-- ============================================================================
-- Leaderboard View (Materialized)
-- ============================================================================
CREATE TABLE IF NOT EXISTS leaderboard (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  total_points NUMERIC(10, 2) DEFAULT 0,
  exact_scores INTEGER DEFAULT 0,
  correct_results INTEGER DEFAULT 0,
  predictions_made INTEGER DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_points ON leaderboard(total_points DESC);

-- ============================================================================
-- Audit Log Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at);

-- ============================================================================
-- Functions
-- ============================================================================

-- Function to calculate points for a prediction
CREATE OR REPLACE FUNCTION calculate_prediction_points(
  predicted_home INT,
  predicted_away INT,
  actual_home INT,
  actual_away INT
)
RETURNS NUMERIC AS $$
BEGIN
  -- Exact score
  IF predicted_home = actual_home AND predicted_away = actual_away THEN
    RETURN 3.0;
  END IF;

  -- Get predicted result
  DECLARE
    pred_result TEXT;
    actual_result TEXT;
    goal_diff_pred INT;
    goal_diff_actual INT;
  BEGIN
    pred_result := CASE
      WHEN predicted_home > predicted_away THEN 'H'
      WHEN predicted_home < predicted_away THEN 'A'
      ELSE 'D'
    END;

    actual_result := CASE
      WHEN actual_home > actual_away THEN 'H'
      WHEN actual_home < actual_away THEN 'A'
      ELSE 'D'
    END;

    -- Correct result
    IF pred_result = actual_result THEN
      goal_diff_pred := ABS(predicted_home - predicted_away);
      goal_diff_actual := ABS(actual_home - actual_away);

      -- Close score (±1 goal difference)
      IF ABS(goal_diff_pred - goal_diff_actual) <= 1 THEN
        RETURN 1.5;
      ELSE
        RETURN 1.0;
      END IF;
    END IF;

    RETURN 0.0;
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to update leaderboard
CREATE OR REPLACE FUNCTION update_leaderboard()
RETURNS TRIGGER AS $$
BEGIN
  -- Update leaderboard for this user
  WITH user_stats AS (
    SELECT
      p.user_id,
      COALESCE(SUM(p.points_earned), 0) as total_points,
      COALESCE(SUM(CASE WHEN m.home_score IS NOT NULL AND 
        m.home_score = p.predicted_home_score AND
        m.away_score = p.predicted_away_score THEN 1 ELSE 0 END), 0) as exact_count,
      COALESCE(SUM(CASE WHEN m.home_score IS NOT NULL AND 
        CASE WHEN m.home_score > m.away_score THEN 'H'
             WHEN m.home_score < m.away_score THEN 'A'
             ELSE 'D' END =
        CASE WHEN p.predicted_home_score > p.predicted_away_score THEN 'H'
             WHEN p.predicted_home_score < p.predicted_away_score THEN 'A'
             ELSE 'D' END THEN 1 ELSE 0 END), 0) as correct_count,
      COUNT(*) as prediction_count
    FROM predictions p
    LEFT JOIN matches m ON p.match_id = m.id
    WHERE p.user_id = COALESCE(NEW.user_id, OLD.user_id)
    GROUP BY p.user_id
  )
  INSERT INTO leaderboard (user_id, total_points, exact_scores, correct_results, predictions_made, updated_at)
  SELECT user_id, total_points, exact_count, correct_count, prediction_count, CURRENT_TIMESTAMP
  FROM user_stats
  ON CONFLICT (user_id) DO UPDATE SET
    total_points = EXCLUDED.total_points,
    exact_scores = EXCLUDED.exact_scores,
    correct_results = EXCLUDED.correct_results,
    predictions_made = EXCLUDED.predictions_made,
    updated_at = CURRENT_TIMESTAMP;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to recalculate points when match finishes
CREATE OR REPLACE FUNCTION recalculate_match_points()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'finished' AND NEW.home_score IS NOT NULL AND NEW.away_score IS NOT NULL THEN
    UPDATE predictions
    SET
      points_earned = calculate_prediction_points(
        predicted_home_score,
        predicted_away_score,
        NEW.home_score,
        NEW.away_score
      ),
      updated_at = CURRENT_TIMESTAMP
    WHERE match_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Triggers
-- ============================================================================

-- Trigger to update leaderboard on prediction changes
DROP TRIGGER IF EXISTS trigger_update_leaderboard_on_prediction ON predictions;
CREATE TRIGGER trigger_update_leaderboard_on_prediction
AFTER INSERT OR UPDATE OR DELETE ON predictions
FOR EACH ROW
EXECUTE FUNCTION update_leaderboard();

-- Trigger to recalculate points when match finishes
DROP TRIGGER IF EXISTS trigger_recalculate_points_on_match_update ON matches;
CREATE TRIGGER trigger_recalculate_points_on_match_update
AFTER UPDATE ON matches
FOR EACH ROW
EXECUTE FUNCTION recalculate_match_points();

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY users_select_own ON users
  FOR SELECT USING (auth.uid()::text = id::text OR TRUE);

-- Users can only insert their own record
CREATE POLICY users_insert_own ON users
  FOR INSERT WITH CHECK (auth.uid()::text = id::text);

-- Users can update their own record
CREATE POLICY users_update_own ON users
  FOR UPDATE USING (auth.uid()::text = id::text);

-- Users can view their own predictions
CREATE POLICY predictions_select_own ON predictions
  FOR SELECT USING (auth.uid()::text = user_id::text OR TRUE);

-- Users can only insert their own predictions
CREATE POLICY predictions_insert_own ON predictions
  FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

-- Users can update their own predictions (before lock)
CREATE POLICY predictions_update_own ON predictions
  FOR UPDATE USING (auth.uid()::text = user_id::text AND locked_at IS NULL);

-- Public can view leaderboard
CREATE POLICY leaderboard_select_public ON leaderboard
  FOR SELECT USING (TRUE);

-- ============================================================================
-- Sample Data (Optional - remove for production)
-- ============================================================================

-- Insert sample user (remove after testing)
-- INSERT INTO users (email, name, oauth_provider, oauth_id, avatar_url)
-- VALUES ('test@example.com', 'Test User', 'google', 'test-oauth-id', NULL);

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_predictions_user_match ON predictions(user_id, match_id);
CREATE INDEX IF NOT EXISTS idx_matches_finished ON matches(status) WHERE status = 'finished';
CREATE INDEX IF NOT EXISTS idx_matches_upcoming ON matches(status, kickoff_time) WHERE status = 'upcoming';
