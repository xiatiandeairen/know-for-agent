# Know — X (Twitter) Chinese-region Promotion Plan

Main battleground: X Chinese region (@AI tools / Claude Code / indie-dev circle)
Monetization path: Platform D revenue share (X blue-check ad-revenue + Xiaohongshu/Zhihu later as low-bar follow-ups)
Current status: <500 followers, real name OK
v1 goal: grow to 500+ followers within 21 days (the X blue-check revenue-share threshold)
v2 goal (kicks off after Day 21): enable blue check + add Xiaohongshu/Zhihu as second platforms

---

## ⚠ Real Constraints

X blue-check ad-revenue hard threshold: 500+ followers + 5M cumulative impressions over 90 days + Premium subscription.
There will be no revenue share at all during v1 — this is a **groundwork phase**. The short-term "make money" path can only ride after v2, or path B (paid community, not the main pitch in this plan).

---

## 1. Pre-launch checklist (must verify in the 24h before posting)

- [ ] GitHub repo is public and the link opens
- [ ] X profile bio updated to: "AI engineering / heavy Claude Code user / {real name}\nBuilding know: let AI remember what is actually worth remembering"
- [ ] X profile header image identifies the person (suggest a light background + know logo or a one-line slogan)
- [ ] Avatar is clear (real person / consistent avatar; avoid abstract icons)
- [ ] Posting time locked: **Tuesday or Wednesday 21:30 UTC+8**
- [ ] Hero image in place (path: `docs/marketing/assets/hero.png`)

## 2. Hero image (already generated)

**Use only one image: `docs/marketing/assets/hero.png`** (1200×1200)

Visual logic: the top half shows 9 real CLAUDE.md rules — 7 generic rules struck through in red ("the model already knows this"), and the bottom 3 with concrete business context highlighted in green ("actually carries information entropy"). Bottom: one-line summary + GitHub link.

The main post uses this single image. The 3 replies are pure text (an info-overloaded image actually dilutes the impact of the hero).

---

## 3. First wave content (final draft, copy-paste ready)

### Main post (154 Chinese characters + 1 image = `hero.png`)

```
Three months into Claude Code, what kills me isn't that it's dumb — it's that it forgets.

The mistake I corrected last week, it makes again in a fresh chat.
Stuffing CLAUDE.md with rules doesn't save you — the longer it gets, the lazier it reads.

So I built know — 5 gates for CLAUDE.md:
not enough information entropy, won't fire again, can't say when it expires — all rejected.

Let the AI remember what's actually worth remembering.

🔗 https://github.com/xiatiandeairen/know-for-agent
```

### Reply 1 (self-reply to the main post, pure text)

```
The 5 gates, concretely:

1. Information entropy — isn't this just common knowledge?
2. Reuse — will it fire again?
3. Trigger — is "when" specific enough?
4. Actionable — is "do what" something a machine can run?
5. Invalidation — under what condition does this entry expire?

Get blocked at any one of them, and the rule does not enter CLAUDE.md.
```

### Reply 2 (self-reply to Reply 1, pure text)

```
The best part: it rejects about 1/3 of the rules I try to write myself.

Yesterday I tried to make it remember "run tests before commit" — blocked at gate 1: that's common knowledge, doesn't go in.
A flat "a capable model already knows this" pushed me back.
```

### Reply 3 (self-reply to Reply 2, no image)

```
Want to try: https://github.com/xiatiandeairen/know-for-agent

Feedback: DM or open an issue.
```

---

## 4. Follow-up 21-day content (Chinese-version angle series)

> Only post angle 1 if the main post hits ≥1k reads; under 500 reads, go back and re-do the hook — don't burn an angle.

### Day 3 — Angle 1: the counterintuitive 5 gates

```
I used to think the more detail in CLAUDE.md, the more useful it was.

A month later: the exact opposite. 80% of the rules I wrote in there, Claude wasn't actually following.
Not because it didn't read them — because after reading, it judged "this carries too little information entropy, not worth keeping as a constraint".

So I flipped it: I bolted 5 filter gates onto CLAUDE.md proactively,
so that anything that gets through is something the model wouldn't do by default.

CLAUDE.md shrank from 200 lines to 30. Claude got noticeably more obedient.
```

### Day 7 — Angle 2: stop the AI from making up numbers

```
I'm done with Claude inventing numbers in tech docs.

"Estimated 30% latency reduction, throughput doubled, $4k/mo savings" —
no source, no premise. Sounds like a human phoning it in.

So in the know write pipeline I added a hard rule:
every number must carry a tag —
[measured] / [estimated] / [target] / [no data]
No tag? The doc just won't generate.

In review I finally know which data point to interrogate.
```

### Day 12 — Angle 3: [correction] and [capture] are two different things

```
Two kinds of feedback. Using the same filter for both is wrong:

[correction] = you stopped, manually edited the AI's output, and explained why.
→ This bypasses the entropy gate — what you stopped to fix is by definition worth remembering.

[capture] = the AI says "I noticed this pattern".
→ Run all 5 gates, default reject. Most of these are it overfitting on noise.

Mix them up, and CLAUDE.md becomes the AI's stream of consciousness.
```

### Day 18 — Angle 4: you don't need a memory service

```
I keep seeing people bolt "long-term memory" onto Claude —
vector stores, knowledge graphs, dedicated memory daemons.

Claude Code already has one:
it walks up from the current file's directory, reading every CLAUDE.md, auto-merging.

So "routing a rule to the right scope" just means dropping it in the right directory:
~/.claude/CLAUDE.md     → cross-project
repo/src/auth/CLAUDE.md → this module
repo/CLAUDE.md          → the whole project

Zero runtime, zero daemon, zero new concept.
know's only job is filtering what gets written. It does not invent a loading mechanism.
```

---

## 5. Cadence Table

| Day | Time slot (UTC+8) | Content | Notes |
|-----|-------------------|---------|-------|
| T+0 | Tue/Wed 21:30 | Main post + 3 self-replies | with 3 images |
| T+1h | — | Verify all self-replies are in place, no typos | |
| T+24h | — | Reply on big-account threads (see §6 list) | no spamming, lead with concrete examples |
| T+3 | 21:30 | Angle 1 (decide based on main-post numbers) | bad numbers → rewrite the hook and re-pitch |
| T+7 | 21:30 | Angle 2 | |
| T+12 | 21:30 | Angle 3 | |
| T+18 | 21:30 | Angle 4 | |
| T+21 | — | Retrospective: follower delta / repo clones / issues / DMs | decide whether to enter v2 |

Posting constraints:
- Post on weekdays; avoid weekends and Chinese public holidays
- ≥3-day gap between posts (X algorithm down-ranks dense same-topic posts)
- Within 24h of each post, manually self-reply (props impressions, draws Q&A)

---

## 6. Reply-engineering (ongoing, starting T+1d)

Target accounts (active voices in the Chinese AI tooling / Claude Code / dev-productivity circle):

- @宝玉 (dotey)
- @乌冬蛋糕
- @karminski-牙医
- @indigo11
- @chyx (CHYX)
- @plutoless
- @geekan
- @tom_doerr (active in both Chinese and English)

Operating procedure:
- Every 2-3 days, drop a comment under their recent (past 7 days) posts on relevant topics (AI memory / Claude Code / agent tooling / CLAUDE.md / Cursor comparison)
- Comment principle: **lead with a concrete example**, no hard pitch. For example:
  - They post "Cursor rules keep getting ignored" → you reply "We built a 5-gate filter; after killing 30% of low-entropy rules, both Cursor and Claude got more obedient: {link}"
  - They post "CLAUDE.md keeps growing" → you reply "Hit the same wall, recently shipped a tool that auto-filters: {link}"
- **Never** drop "follow / RT please" begs under their posts

---

## 7. Retrospective Metrics (Day 21)

Measured items (no preset targets, record only):

| Metric | Tool |
|--------|------|
| Main post + 4 angles per-post stats (impressions / likes / RT / replies / bookmarks) | X analytics |
| Net follower gain | X dashboard |
| GitHub clone count | `gh api repos/xiatiandeairen/know-for-agent/traffic/clones` |
| Issue count + content quality | GitHub |
| High-quality DM/reply count (with concrete usage detail) | manual notes |

**Decision branches**:

| Status | Action |
|--------|--------|
| Followers +200 + clones ≥30 + ≥3 real-feedback items | Kick off v2: add Xiaohongshu + Zhihu, prep for X blue-check |
| Followers +50 ~ +200 | Hold the cadence, observe for another 21 days |
| Followers <50 | Retrospective on hook / audience mismatch; possibly pivot to path B (paid community) |

---

## 8. Open Questions (for the user to answer)

- ~~GitHub repo public~~ ✓ https://github.com/xiatiandeairen/know-for-agent
- Is X blue check subscribed yet? Must be subscribed before kicking off v2
- Real name in X profile bio: replace `{real name}` in the drafts above with the real name before posting

---

## 9. Out-of-scope items

- No paid ads, no follow-bombing, no engagement farming
- No @-ing big accounts in the main post (in the Chinese circle, @-begging for follows is a negative signal)
- No syncing to Xiaohongshu/Zhihu within the 21 days (handle in v2 to avoid splitting focus)
- No video (A4 already excluded; defer to v3)
