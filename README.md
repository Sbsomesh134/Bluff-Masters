# Bluff Masters

A responsive, real-time bluffing and trivia party game. The React client is deliberately a thin UI: all room actions, deadlines, private answer reads, voting checks, and scoring run through the Supabase Edge Function and transactional PostgreSQL functions.

## Requirements

- Node.js 20 or newer and npm
- A Supabase project (free tier is sufficient for development)
- Supabase CLI for applying migrations and deploying Edge Functions
- Netlify account only when publishing the frontend

## Local frontend

1. Install dependencies:

   ```sh
   npm install
   ```

2. Create `.env.local` from `.env.example` and set the project URL and publishable/anon key:

   ```env
   VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
   VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
   ```

   These are public browser settings. **Never put a service-role or secret key in a `VITE_*` variable.**

3. Start the Vite development server:

   ```sh
   npm run dev
   ```

   Open the URL Vite prints (normally `http://localhost:5173`). Without the Supabase environment values, the interface can load but game actions correctly report that backend configuration is missing.

## Supabase setup

1. Create a Supabase project and note its project reference, URL, and publishable/anon key.
2. In Supabase Dashboard → Authentication → Providers, enable **Anonymous sign-ins**. The included supabase/config.toml also enables anonymous sign-ins for local Supabase. Guest identity is a Supabase anonymous-auth user, not a manually registered account. The session is persisted in that browser for reconnection.
3. Install the Supabase CLI using the official Supabase instructions, authenticate, then link this project:

   ```sh
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   ```

4. Apply migrations in order. The migrations create a 112-question bank, rooms, players, round/submission/vote/report tables, RLS, realtime publication, scoring logic, phase actions, private question reports, randomized answer order, and expiry handling:

   ```sh
   supabase db push
   ```

   Files are in `supabase/migrations/`. For a new database, all five migrations apply in timestamp order. They include the RLS membership helper, browser-safe state responses, avatar validation, duplicate-safe deadlines, reporting, and correct-answer randomization.

5. Deploy the server-only game action:

   ```sh
   supabase functions deploy game-action
   ```

   The function validates the caller's Supabase Auth JWT and resolves its user ID. It uses the Supabase service-role key only in the Edge Function environment to call `game_action`. Supabase normally provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to deployed functions. Check the function's environment in the Dashboard if your project uses a different key setup. Do not copy the service key to this repository or Netlify.

6. Optionally restrict Edge Function CORS to your real origins. By default, the function allows cross-origin calls and relies on the signed-in JWT, RLS, and server validation. For an explicit origin, set the server secret:

   ```sh
   supabase secrets set ALLOWED_ORIGIN=https://YOUR-SITE.netlify.app
   ```

   For local Vite development, add `http://localhost:5173` as an allowed origin while testing. If using multiple origins, adjust the Edge Function CORS response to an allowlist before deployment.

7. In Supabase → Database → Publications, confirm that `rooms` and `players` are in `supabase_realtime`. The initial migration adds them when the publication exists. Realtime payloads contain only safe room phase, deadline, roster, and score columns. Private tables have no client-select policies and are not published.

## Security model

- Anonymous Auth gives each guest a stable `auth.uid()` between refreshes and reconnects. Players are not required to create an account.
- Browser actions go to `game-action`. It validates the bearer JWT; PostgreSQL then validates room membership, host permissions, phase, deadlines, answer length, vote choice, self-votes, and duplicate writes.
- PostgreSQL is authoritative. All scoring is transactional and stored once per player/round. Deadline transitions are idempotent. A browser countdown is only a display; an expired action cannot be accepted.
- RLS permits room members to read only safe room and player rows. Submission, answer-option, vote, question, and score tables do not grant browser reads. A per-player game-state response omits unrevealed correct answers, other players' submitted text, and votes.
- Service-role credentials are server-only. The frontend has only the Supabase URL and public publishable/anon key.

## Tests

Run frontend checks:

```sh
npm test
npm run build
```

A transactional database scenario is in `supabase/tests/transactional_game.sql`. Run it after migrations against a disposable local Supabase database or a non-production project; it creates a room, plays a round, and asserts score/reveal behavior. Never run destructive experiments against production data.

For local Supabase development, use:

```sh
supabase start
supabase db reset
supabase test db
supabase functions serve game-action --env-file supabase/.env.local
```

Create `supabase/.env.local` for the local Edge Function's Supabase URL, anon key, and service-role key. Keep this file out of Git.

## Netlify deployment

1. Push the project to a Git repository and import it into Netlify, or use Netlify CLI.
2. Netlify build settings are in `netlify.toml`: build command `npm run build`, publish directory `dist`. The SPA fallback is configured so room links such as `/?room=ABC123` load correctly.
3. Set these **Site environment variables** in Netlify → Site configuration → Environment variables:
   - `VITE_SUPABASE_URL` = Supabase project URL
   - `VITE_SUPABASE_ANON_KEY` = Supabase publishable/anon key
4. Deploy, then set the deployed Netlify URL as `ALLOWED_ORIGIN` on Supabase if you enabled an origin restriction. Add the preview URL/origin separately when needed.
5. For CLI deployment after linking the site, set the two public build variables and publish with: npx netlify-cli env:set VITE_SUPABASE_URL https://YOUR_PROJECT_REF.supabase.co; npx netlify-cli env:set VITE_SUPABASE_ANON_KEY YOUR_PUBLISHABLE_OR_ANON_KEY; npx netlify-cli deploy --build --prod. Use npx netlify-cli login and npx netlify-cli link first if this site is not linked. You can instead set those two variables in the Netlify dashboard. Netlify reads hosted build variables from site configuration; it does not import local .env files. Never put the service-role key in frontend variables.
6. Verify with two separate browsers/devices: create/join; ready/start; submit; vote; reveal and scoring; complete all eight rounds; rematch; refresh/reconnect. A successful Netlify build alone does not prove Supabase multiplayer is working.

## Commands

```sh
npm install
npm run dev
npm test
npm run build
npm run preview
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase functions deploy game-action
```

## Current MVP behavior and boundaries

- 2–8 players, eight questions per match, 60-second submission and 30-second voting phases.
- The first phase switches to voting when every active player submits; voting switches to reveal when everyone votes. Server deadlines resolve missing actions.
- The host can advance a timed phase early, advance from reveal to the next round, and start a rematch. Ties at the top are co-winners.
- Late joins are blocked after start. Existing players can reconnect with the same anonymous Auth session. Stale seats remain in the match; explicit leave removes a player from the active roster and transfers host control when needed.
- Inactive rooms expire after 24 hours and are removed lazily when another room is created or an expired code is joined; no scheduled cleanup job is configured.
- Expired rooms are removed lazily when a new room is created or an expired code is joined; there is no scheduled cleanup job.
- Cross-device production multiplayer cannot be verified until a Supabase project and Netlify site are configured.

The trivia report button stores private reports for review and does not publish them to other players. Host removal is available only in the lobby. Inactive room cleanup is lazy: expired rooms are deleted when a new room is created, and expired room codes are rejected on join.
