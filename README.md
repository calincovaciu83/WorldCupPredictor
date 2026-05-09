# World Cup 2026 Predictor

A full-stack web application where friends compete by predicting World Cup 2026 match scores. Built with Next.js, React, TypeScript, Supabase, and Football-Data API.

## 🎯 Features

- **Social Authentication**: Sign in with Google or GitHub
- **Live Match Data**: Auto-synced from Football-Data.org API
- **Score Predictions**: Predict match results before they happen
- **Smart Scoring**: 3pts for exact score, 1.5pts for close, 1pt for correct result
- **Real-time Leaderboard**: Compete with friends
- **Auto Result Updates**: Matches update automatically when completed
- **User Accounts**: Persistent predictions and statistics

## 🛠 Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript, Tailwind CSS
- **Backend**: Next.js API Routes
- **Database**: PostgreSQL (Supabase)
- **Auth**: NextAuth.js with OAuth2 (Google, GitHub)
- **External API**: Football-Data.org
- **Deployment**: Vercel recommended

## 📋 Database Schema

### Users
```sql
- id (UUID, PK)
- email (unique)
- name
- oauth_provider (google | github)
- avatar_url
- created_at
```

### Matches
```sql
- id (UUID, PK)
- match_id (external API ID, unique)
- home_team
- away_team
- kickoff_time
- status (upcoming | live | finished)
- home_score
- away_score
- group
- venue
- synced_at
```

### Predictions
```sql
- id (UUID, PK)
- user_id (FK to users)
- match_id (FK to matches)
- predicted_home_score
- predicted_away_score
- points_earned
- locked_at
- created_at
```

### Leaderboard
```sql
- user_id (FK to users)
- total_points
- exact_scores
- correct_results
- predictions_made
- updated_at
```

## 🚀 Getting Started

### 1. Prerequisites
- Node.js 18+
- PostgreSQL (via Supabase)
- Football-Data.org API key (free tier)
- Google/GitHub OAuth credentials

### 2. Setup Supabase
1. Create account at [supabase.com](https://supabase.com)
2. Create new project
3. Run SQL migrations from `database/migrations/001_initial_schema.sql`
4. Get your `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`

### 3. Setup OAuth Providers

**Google:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create OAuth 2.0 Client ID (Web application)
3. Add `http://localhost:3000/api/auth/callback/google` to redirect URIs

**GitHub:**
1. Go to Settings → Developer settings → OAuth Apps
2. Create new OAuth App
3. Set Authorization callback URL to `http://localhost:3000/api/auth/callback/github`

### 4. Get Football-Data API Key
1. Sign up at [football-data.org](https://www.football-data.org)
2. Free tier includes World Cup data
3. Copy your API token

### 5. Configure Environment
```bash
cp .env.example .env.local
# Fill in all variables
```

### 6. Install & Run
```bash
npm install
npm run dev
```

Visit `http://localhost:3000`

## 📁 Project Structure

```
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   └── callback/
│   ├── (dashboard)/
│   │   ├── page.tsx          # Main dashboard
│   │   ├── leaderboard/
│   │   └── stats/
│   ├── api/
│   │   ├── auth/             # NextAuth routes
│   │   ├── matches/          # Match data endpoints
│   │   ├── predictions/      # User predictions
│   │   └── leaderboard/      # Leaderboard data
│   ├── layout.tsx
│   └── page.tsx              # Home redirect
├── lib/
│   ├── supabase.ts           # Supabase client & types
│   ├── football-api.ts       # Football-Data API integration
│   ├── auth.ts               # NextAuth configuration
│   └── utils.ts              # Utility functions
├── database/
│   └── migrations/
│       └── 001_initial_schema.sql
├── components/
│   ├── MatchCard.tsx
│   ├── Leaderboard.tsx
│   ├── Stats.tsx
│   └── Header.tsx
├── public/
├── .env.example
├── tsconfig.json
├── tailwind.config.js
├── next.config.js
└── package.json
```

## 🔑 Environment Variables

Create `.env.local`:

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxx
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx

# NextAuth
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-key-here

# OAuth Providers
GOOGLE_ID=xxx.apps.googleusercontent.com
GOOGLE_SECRET=xxx

GITHUB_ID=xxx
GITHUB_SECRET=xxx

# Football Data API
FOOTBALL_DATA_API_KEY=xxx
```

## 💾 Database Setup

1. Go to Supabase SQL Editor
2. Copy entire contents from `database/migrations/001_initial_schema.sql`
3. Execute all queries
4. Verify tables created: `users`, `matches`, `predictions`, `leaderboard`

## 🔄 API Integration

Matches sync automatically via a scheduled job:
- Fetches World Cup 2026 matches from Football-Data API
- Updates match statuses (upcoming → live → finished)
- Auto-calculates user points when matches finish
- Updates leaderboard materialized view

## 📊 Scoring Rules

| Outcome | Points |
|---------|--------|
| Exact score match | 3 pts |
| Correct result + close score (±1 goal) | 1.5 pts |
| Correct result (W/D/L) | 1 pt |
| Wrong result | 0 pts |

## 🎨 Design Integration

Your design (`world_cup_predictor.html`) is ready to integrate:
- CSS variables already defined
- Component structure matches your mockup
- Dark theme optimized for competitive gaming

Components to create:
- `components/MatchCard.tsx` - Individual match prediction card
- `components/Leaderboard.tsx` - Rankings table
- `components/Stats.tsx` - User statistics dashboard

## 🚢 Deployment

### Deploy to Vercel (Recommended)

1. Push code to GitHub
2. Connect repo to Vercel
3. Add environment variables in Vercel dashboard
4. Deploy!

```bash
git push origin main
```

### Self-hosted

```bash
npm run build
npm run start
```

## 🐛 Development

```bash
# Run dev server
npm run dev

# Run linting
npm run lint

# Build for production
npm run build
```

## 📝 API Endpoints

### Matches
- `GET /api/matches` - Get all WC2026 matches
- `GET /api/matches/[id]` - Get match details
- `POST /api/matches/sync` - Sync from Football-Data (admin only)

### Predictions
- `GET /api/predictions` - Get user's predictions
- `POST /api/predictions` - Create/update prediction
- `GET /api/predictions/[matchId]` - Get predictions for match

### Leaderboard
- `GET /api/leaderboard` - Get rankings
- `GET /api/leaderboard/[userId]` - Get user stats

## 🔐 Security

- Row-level security (RLS) on Supabase
- NextAuth session management
- CSRF protection
- Environment variable isolation
- OAuth credential encryption

## 📞 Support

For issues or questions:
1. Check existing GitHub Issues
2. Create new issue with details
3. Include: OS, Node version, error message

## 📄 License

MIT

---

**Made with ⚽ and ☕ by calincovaciu83**
