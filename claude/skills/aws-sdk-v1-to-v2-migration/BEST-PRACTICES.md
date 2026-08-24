# Best Practices for Working with Claude Skills

**For: AWS SDK v1 to v2 Migration Skill**
**Date Created:** 2026-02-09

---

## Table of Contents

1. [Reading & Understanding Skills](#reading--understanding-skills)
2. [Using Skills During Work](#using-skills-during-work)
3. [Updating Skills (TDD Approach)](#updating-skills-tdd-approach)
4. [Sharing Skills](#sharing-skills)
5. [Migration Workflow](#migration-workflow)
6. [Quick Reference Commands](#quick-reference-commands)

---

## Reading & Understanding Skills

### Progressive Reading Strategy

Skills are **reference guides, not novels**. Read progressively:

```
Overview → Quick Reference → Phase Needed → Deep Dive
```

**Before Starting Any Migration:**

| Section | Time | Purpose |
|---------|------|---------|
| Overview | 30 sec | Understand core principle |
| When to Use | 30 sec | Confirm skill applies |
| Migration Phases (diagram) | 30 sec | See the journey |
| Quick Reference table | 1 min | Core v1→v2 mappings |
| Verification Checklist | 2 min | Know definition of done |

**Total: ~5 minutes** to be ready to start

**During Migration:**
- Jump to specific phases as needed
- Reference Quick Reference table frequently
- Check Common Mistakes when stuck
- Use Definition of Done to track progress

### Keep Skill Accessible

```bash
# Option 1: Open in editor (recommended)
code ~/.claude/skills/aws-sdk-v1-to-v2-migration/SKILL.md

# Option 2: Split terminal - code on one side, skill on other
tmux split-window -h
# Left: your work | Right: less SKILL.md

# Option 3: Browser with Markdown viewer
# Option 4: Print Quick Reference and pin to wall
```

**Pro tip:** Keep skill open in a separate window/screen throughout migration.

---

## Using Skills During Work

### Invoking Skills in Claude

When starting work, be explicit:

```
"I want to migrate recs-validation from AWS SDK v1 to v2.
Use the aws-sdk-v1-to-v2-migration skill."
```

Or use shorthand:
```
"/aws-sdk-v1-to-v2-migration"
```

Claude will:
1. Load the skill
2. Follow it systematically
3. Reference specific phases as needed
4. Help you stay on track

### Referencing Specific Sections

During work, ask targeted questions:

- "What does Phase 5 say about LIST operations?"
- "Check Common Mistakes for assembly issues"
- "Show me the region configuration pattern"
- "What's the Definition of Done?"

### Using as a Checklist

Track progress through phases:

```markdown
## recs-validation Migration Progress

- [x] Phase 1: Audit v1 usage
- [x] Phase 2: Update dependencies
- [x] Phase 3: Fix imports
- [ ] Phase 4: Update client creation
- [ ] Phase 5: Migrate operations
- [ ] Phase 6: Update model classes
- [ ] Phase 7: Update exception handling
- [ ] Phase 8: Update tests
- [ ] Phase 9: Handle class name conflicts
- [ ] Phase 10: Update build configuration
- [ ] Phase 11: Assembly verification (CRITICAL)
```

---

## Updating Skills (TDD Approach)

### The Iron Law

**NO SKILL UPDATES WITHOUT TESTING FIRST**

Just like code: test what you're adding works before documenting it.

### When to Update

Update the skill when you encounter:

1. **Missing patterns** - "The skill doesn't cover DynamoDB encryption"
2. **Wrong guidance** - "This approach doesn't work with Scala 2.13"
3. **New errors** - "Hit an assembly error not in the troubleshooting guide"
4. **Better approaches** - "Found a cleaner way to handle region config"
5. **Ambiguous instructions** - "I wasn't sure what 'update imports' meant"

### RED-GREEN-REFACTOR for Skills

**❌ WRONG Approach:**
```
1. Hit a problem during migration
2. Fix it somehow
3. Immediately update skill
4. Continue work
```

**✅ CORRECT Approach (TDD for Documentation):**

#### RED Phase - Document What Failed

```markdown
## Problem Encountered

**Issue:** Assembly failed with Jackson version conflict

**Error:**
```
[error] Modules were resolved with conflicting cross-version suffixes:
[error]    com.fasterxml.jackson.core:jackson-databind _2.13
```

**What I tried:**
1. Excluding Jackson from v2 SDK → didn't work
2. Setting explicit Jackson version → conflicts
3. Upgrading RecsPlugin to 2.1.3 → WORKED!

**Why it failed:** Old RecsPlugin (2.0.25) had Jackson versions
incompatible with v2 SDK
```

#### GREEN Phase - Solution Found & Tested

```markdown
## Solution (TESTED ✓)

**Root cause:** RecsPlugin 2.0.25 provides Jackson versions for v1 SDK

**Solution:**
1. Update to RecsPlugin 2.1.3 (provides v2-compatible Jackson)
2. Remove any explicit Jackson dependencies
3. Let RecsPlugin manage all Jackson versions

**Verification:**
```bash
sbt clean
sbt dependencyTree | grep jackson  # Shows 2.1.3 versions
sbt assembly  # SUCCESS ✓
```

**Tested in:** recs-validation project
**Date:** 2026-02-09
```

#### REFACTOR Phase - Update Skill

```markdown
## Skill Updates Needed

**Section:** Phase 11: Assembly Verification

**Add troubleshooting entry:**

### Error: Module collision with Jackson

**Symptom:**
[exact error message]

**Cause:** [explanation]

**Fix:** [step-by-step solution]

**Verification checklist addition:**
- [ ] RecsPlugin 2.1.3 used (not 2.0.25)
- [ ] No explicit Jackson dependencies in build.sbt
```

#### TEST Phase - Clarity Check

Ask yourself:
- [ ] Would someone else understand this error from the symptom?
- [ ] Is the root cause clearly explained?
- [ ] Is the solution actionable (step-by-step)?
- [ ] Did I include verification steps?
- [ ] Have I tested this solution works?

### Practical Update Workflow

```bash
# 1. Create a learnings file during migration
cat > ~/.claude/skills/aws-sdk-v1-to-v2-migration/migration-learnings.md << 'EOF'
# Migration Learnings - recs-validation
Date: 2026-02-09

## Issue 1: [Title]
**Problem:** ...
**Solution:** ...
**Tested:** ✓

## Issue 2: [Title]
...
EOF

# 2. As you hit issues, document them immediately
echo "## Issue: Assembly Jackson conflict" >> migration-learnings.md
echo "Problem: ..." >> migration-learnings.md
echo "Solution: ..." >> migration-learnings.md

# 3. After migration completes, review learnings
cat migration-learnings.md

# 4. For each learning, update SKILL.md
code SKILL.md
# Add to appropriate section with tested solutions

# 5. Archive learnings
mv migration-learnings.md completed-migrations/recs-validation-2026-02-09.md
```

### Where to Add Updates

| Issue Type | Add To Section |
|------------|----------------|
| New error during assembly | Phase 11: Assembly Verification |
| Better code pattern | Relevant phase (e.g., Phase 5 for LIST ops) |
| Common mistake | Common Mistakes table |
| New AWS service | Other AWS Services section |
| Verification step | Verification Checklist |
| Time estimate wrong | Real-World Impact |

---

## Sharing Skills

### Option 1: Git Version Control (Recommended)

```bash
# Initialize git in skill directory
cd ~/.claude/skills/aws-sdk-v1-to-v2-migration
git init

# Create .gitignore
cat > .gitignore << 'EOF'
*.log
migration-learnings.md
*-notes.md
EOF

# Commit skill
git add SKILL.md BEST-PRACTICES.md
git commit -m "Initial AWS SDK v1 to v2 migration skill"

# Push to team repo
git remote add origin git@github.com:your-org/claude-skills.git
git push -u origin main
```

**Benefits:**
- Version control (see skill evolution)
- Team collaboration (PRs, reviews)
- Change tracking (who changed what, when)
- Rollback capability

**Team workflow:**
```bash
# Team member clones skill
cd ~/.claude/skills
git clone git@github.com:your-org/claude-skills.git aws-sdk-v1-to-v2-migration

# Pull updates before migration
cd aws-sdk-v1-to-v2-migration
git pull

# Share improvements
git add SKILL.md
git commit -m "Add DynamoDB conditional writes pattern"
git push
```

### Option 2: Shared Network Location

```bash
# One-time setup: Copy to shared location
cp -r ~/.claude/skills/aws-sdk-v1-to-v2-migration \
     /shared/team/claude-skills/

# Team members create symlink
ln -s /shared/team/claude-skills/aws-sdk-v1-to-v2-migration \
      ~/.claude/skills/aws-sdk-v1-to-v2-migration

# Update shared version
cp SKILL.md /shared/team/claude-skills/aws-sdk-v1-to-v2-migration/
```

**Benefits:**
- Simple (no git knowledge needed)
- Automatic updates (symlink always current)

**Drawbacks:**
- No version control
- No change tracking
- Overwrite risks

### Option 3: Internal Wiki/Confluence

```bash
# Export to wiki-friendly format
# (Remove diagrams, simplify tables)

# Add to team wiki
# Link from project README
```

**Benefits:**
- Discoverable (team can search wiki)
- Integrated with other docs

**Drawbacks:**
- Not usable by Claude directly
- Manual sync required
- Format conversions needed

### Option 4: Contribute to Open Source (If Broadly Useful)

If skill becomes valuable beyond your organization:

```bash
# Fork superpowers or create new repo
# Polish skill for public consumption
# Submit PR to Anthropic or community repo
```

**When to open source:**
- Pattern applies to many organizations
- No proprietary information
- Well-tested and documented

---

## Migration Workflow

### Before Starting Migration

**1. Preparation (15 minutes)**

```bash
# Create project-specific notes file
touch ~/.claude/skills/aws-sdk-v1-to-v2-migration/recs-validation-notes.md

# Create migration log
cat > migration-log.md << 'EOF'
# recs-validation AWS SDK v1→v2 Migration
Date: 2026-02-09
Migrator: [Your Name]

## Pre-Migration Audit
- [ ] Read skill overview
- [ ] Identify AWS services used
- [ ] Document current dependencies
- [ ] Check internal library versions

## Progress Tracker
[Copy phase checklist from skill]

## Issues Log
[Document problems and solutions as you go]
EOF

# Open skill for reference
code ~/.claude/skills/aws-sdk-v1-to-v2-migration/SKILL.md

# Set AWS_REGION for testing
export AWS_REGION=us-east-1
```

**2. Read Key Sections (5 minutes)**

- [ ] Overview
- [ ] When to Use
- [ ] Migration Phases diagram
- [ ] Quick Reference table
- [ ] Definition of Done

**3. Audit Current State (varies by project)**

```bash
# Run audit commands from Phase 1
grep -r "import com.amazonaws" --include="*.scala" .
grep -E "aws-java-sdk|awscala" build.sbt
sbt dependencyTree | grep amazonaws

# Document findings in migration-log.md
```

### During Migration

**Follow phases sequentially:**

```
Phase 1 → Phase 2 → Phase 3 → ... → Phase 11
```

**Don't skip phases.** Each builds on the previous.

**For each phase:**

1. **Read phase description**
2. **Follow instructions**
3. **Verify completion** (run relevant tests)
4. **Document issues** (if any)
5. **Tick off phase** in progress tracker

**When stuck:**

1. Check **Common Mistakes** table
2. Review **Quick Reference** for mappings
3. Check **Phase-specific troubleshooting**
4. Document issue for later skill update
5. Ask Claude with skill context

**Track time:**

```markdown
## Time Log

Phase 1: Audit - 30 min
Phase 2: Dependencies - 20 min
Phase 3: Imports - 45 min (issue: naming conflict with internal lib)
Phase 4: Client creation - 15 min
...
```

### After Each Phase

```bash
# Commit progress (if using git)
git add .
git commit -m "Phase 3 complete: Updated all imports to v2"

# Run relevant tests
sbt test  # After Phase 8
sbt it:test  # After Phase 8

# Document learnings
echo "## Phase 3 Learnings" >> migration-learnings.md
echo "- Import conflict with internal S3Client wrapper" >> migration-learnings.md
echo "- Solution: Renamed wrapper to S3ClientWrapper" >> migration-learnings.md
```

### After Migration Completes

**1. Final Verification (MANDATORY)**

```bash
# Run complete verification checklist
sbt clean
sbt evicted
sbt dependencyTree | grep "com.amazonaws"  # Should return NOTHING
sbt dependencyTree | grep "software.amazon.awssdk"  # Should show v2
sbt test
sbt it:test
sbt clean assembly  # MUST succeed

# Verify assembly artifact
ls -lh target/scala-*/your-project-assembly-*.jar
```

**2. Document Migration**

```markdown
## recs-validation Migration - COMPLETE ✓

**Date:** 2026-02-09
**Time taken:** X hours
**Migrator:** [Your Name]

### Statistics
- Files changed: X
- Lines changed: Y
- Issues encountered: Z

### Issues Encountered
1. **Jackson version conflict**
   - Solution: Updated RecsPlugin to 2.1.3
   - Time lost: 1 hour

2. **S3Client naming conflict**
   - Solution: Renamed wrapper to S3ClientWrapper
   - Time lost: 30 min

### Lessons Learned
- Always update RecsPlugin first
- Check for naming conflicts early
- Assembly verification catches issues tests miss

### Skill Updates Needed
- [ ] Add Jackson conflict to troubleshooting
- [ ] Add guidance on wrapper class naming
- [ ] Update time estimates
```

**3. Update Skill**

```bash
# Review migration-learnings.md
cat migration-learnings.md

# Update SKILL.md with tested solutions
code SKILL.md

# Commit skill improvements
cd ~/.claude/skills/aws-sdk-v1-to-v2-migration
git add SKILL.md
git commit -m "Add Jackson conflict troubleshooting (tested in recs-validation)"
git push
```

**4. Archive Logs**

```bash
# Create completed migrations directory
mkdir -p ~/.claude/skills/aws-sdk-v1-to-v2-migration/completed-migrations

# Archive migration artifacts
mv migration-log.md completed-migrations/recs-validation-2026-02-09.md
mv migration-learnings.md completed-migrations/recs-validation-learnings-2026-02-09.md
```

---

## Quick Reference Commands

### Skill Management

```bash
# Read entire skill
cat ~/.claude/skills/aws-sdk-v1-to-v2-migration/SKILL.md

# Read specific section
grep -A 20 "Phase 5:" SKILL.md

# Search for topic
grep -i "region" SKILL.md

# Count phases
grep "^## Phase" SKILL.md | wc -l

# View Quick Reference only
grep -A 30 "Quick Reference" SKILL.md

# View Common Mistakes
grep -A 20 "Common Mistakes" SKILL.md

# View Definition of Done
grep -A 30 "Definition of Done" SKILL.md
```

### During Migration

```bash
# Check for v1 usage
grep -r "com.amazonaws" --include="*.scala" .
grep -r "AmazonS3\|S3ObjectSummary" --include="*.scala" .

# Verify dependencies
sbt dependencyTree | grep amazonaws
sbt evicted

# Quick compile check
sbt compile

# Run specific test
sbt "testOnly *S3ClientSpec"

# Assembly check (quick)
sbt assembly

# Full verification
sbt clean && sbt test && sbt it:test && sbt assembly
```

### Skill Updates

```bash
# Edit skill
code ~/.claude/skills/aws-sdk-v1-to-v2-migration/SKILL.md

# View recent changes (if using git)
git log --oneline -10

# See what changed
git diff SKILL.md

# Commit improvements
git add SKILL.md
git commit -m "Add DynamoDB patterns based on project-X migration"
git push
```

### Collaboration

```bash
# Pull latest skill version
cd ~/.claude/skills/aws-sdk-v1-to-v2-migration
git pull

# See who changed what
git blame SKILL.md

# View skill history
git log --oneline -- SKILL.md

# Share with teammate
git remote add origin git@github.com:your-org/skills.git
git push origin main
```

---

## Tips & Tricks

### Tip 1: Create Project-Specific Notes

```bash
# Before migration
cat > recs-validation-notes.md << 'EOF'
# recs-validation Specific Notes

## Project Context
- Uses internal recs-aws library (check compatibility)
- Has custom S3Client wrapper (naming conflict expected)
- Runs in ECS (AWS_REGION available)

## Deviations from Standard Pattern
- [Document as you find them]

## Questions
- Does recs-aws support v2?
- What version has v2 compatibility?
EOF
```

### Tip 2: Use Split Screen

```
+------------------+------------------+
|                  |                  |
|   Your Code      |   SKILL.md       |
|                  |   (reference)    |
|                  |                  |
+------------------+------------------+
```

### Tip 3: Print Quick Reference

Print and pin to wall:
- Quick Reference table
- Common Mistakes table
- Phase checklist

### Tip 4: Set Up Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc
alias skill='less ~/.claude/skills/aws-sdk-v1-to-v2-migration/SKILL.md'
alias skill-edit='code ~/.claude/skills/aws-sdk-v1-to-v2-migration/SKILL.md'
alias skill-search='grep -i "$1" ~/.claude/skills/aws-sdk-v1-to-v2-migration/SKILL.md'

# Usage:
skill  # Read skill
skill-edit  # Edit skill
skill-search "region"  # Search for region info
```

### Tip 5: Take Screenshots of Errors

When you hit errors:
```bash
# Take screenshot (macOS)
cmd+shift+4

# Save to migration-errors/ folder
mkdir -p migration-errors
# Save screenshot there
# Reference in migration-learnings.md
```

Useful for:
- Updating skill with exact error messages
- Helping teammates who hit same issue
- Remembering context later

---

## The Bottom Line

**Skills are living documents:**

```
Start with current version
    ↓
Follow during work
    ↓
Document learnings
    ↓
Update with tested solutions
    ↓
Share improvements
    ↓
Use improved skill for next project
```

**For your AWS SDK migration:**

1. **Before:** Read skill (5 min), set up notes
2. **During:** Follow phases, document issues
3. **After:** Update skill with learnings, share
4. **Next migration:** Use improved skill, repeat

**Remember:**
- Skills are references, not novels (skim, don't read cover-to-cover)
- Update skills with TDD approach (test solutions before documenting)
- Share improvements (help future-you and teammates)
- Keep evolving (each migration improves the skill)

---

**Next Steps:**

When ready to migrate recs-validation:
1. Read this guide ✓
2. Open SKILL.md for reference
3. Tell Claude: "Use aws-sdk-v1-to-v2-migration skill for recs-validation"
4. Follow Phase 1: Audit
5. Work through phases systematically
6. Document learnings
7. Update skill
8. Use improved skill for kd-recs-validation-app

Good luck! 🚀
