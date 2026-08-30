# SetCatcher Product Strategy

Last updated: August 14, 2026.

## Product in one sentence

SetCatcher is a local-first Mac safety net that automatically protects completed DJ sets, keeps their context attached, and leaves the artist's original files untouched.

## The problem

A DJ set is created in a high-attention environment, but preserving it depends on a fragile chain of manual actions: remembering to record, stopping and saving correctly, finding the file later, naming it, copying it somewhere safe, and reconnecting it with the played-track history. Those tasks usually happen when the DJ is performing, traveling, or packing up.

The result is not merely disorganized storage. DJs lose a record of their creative development, a publishable mix, evidence of a booking, material for review, or a moment they cannot reproduce.

## Product thesis

The finished set deserves its own protection layer, separate from the music library and separate from the DJ software that created it.

SetCatcher wins when it becomes a quiet, trusted habit:

1. It watches or captures the right source.
2. It detects when a set is complete.
3. It creates a protected local archive without mutating the original.
4. It attaches the context available from the DJ workflow.
5. It makes the result easy to find, review, and intentionally export.

## Category and positioning

**Category:** automatic set protection.

**Positioning:** For active DJs who record performances but cannot rely on a perfect post-set filing habit, SetCatcher automatically preserves completed recordings and builds a usable history of the work. Unlike cloud-library products, production suites, or manual recording setups, SetCatcher focuses on the finished set and works without taking custody of the artist's audio.

SetCatcher is not primarily:

- a music-library manager;
- a cloud-storage provider;
- a DJ performance application;
- a mix-editing workstation;
- a publishing or social network;
- a replacement for a separate-device backup.

## Target market

### Primary beta audience

Recording-active Mac DJs using Serato or rekordbox who play at least monthly and do not have a dependable post-set archive habit.

### Expansion audiences

- Traktor, VirtualDJ, and djay Pro users with equivalent recording workflows;
- mobile and event DJs who need a dependable gig record;
- radio and streaming DJs who reconnect recordings with track histories;
- touring and multi-platform DJs whose set history is fragmented across tools;
- teachers and students who review practice sessions.

The addressable audience is broader than the primary beta cohort. Marketing may speak to active DJs broadly, while product validation begins with the users whose pain and supported workflows are strongest.

## Jobs to be done

### Core job

When I finish a set, preserve the recording and enough context to find and understand it later, without requiring another post-gig ritual.

### Supporting jobs

- When I forgot to use the DJ app's Record button, capture the Mac-delivered mix when the operating system and audio route allow it.
- When my setup routes audio through a mixer or interface, let me capture that input directly.
- When the DJ app produces a history export, connect it to the correct set without overwriting my explicit choice.
- When something is not protected, tell me exactly why and what to do next.
- When I want to publish or deliver a set, create a local export package only after I ask.

## Strategic pillars

### 1. Protection before management

The product must reliably preserve the artifact before asking the DJ to tag, edit, sync, or publish it.

### 2. Local-first artist control

Folder Protection, Capture, Library, and local history import work without an account. Audio and full tracklists remain local unless the user explicitly initiates an export or a future opt-in backup.

### 3. Multiple honest safety nets

- **Folder Protection** covers recordings written by DJ software or hardware.
- **App audio Capture** covers mixes delivered through Mac system audio when Record/Save was forgotten.
- **Input device Capture** covers mixer and USB-interface routes.

No single method works for every booth. The product should recommend the best verified method and clearly describe fallback paths.

### 4. Compatibility without overclaiming

Support labels describe tested capability, not brand presence. `Supported`, `Partial`, `Manual Setup`, and `Research` must never be rounded upward for marketing convenience.

### 5. Proof builds trust

SetCatcher should show what it protected, when it did so, where the copy lives, whether the source remains reachable, and when it will check again. Trust is earned through receipts and recoverable states.

## Product principles

- Never delete, move, rename, or mutate a source recording.
- Never overwrite an existing archive file.
- Never require an account for local protection.
- Never upload audio or full tracklists by default.
- Never imply that a local archive on the same disk is a complete disaster-recovery backup.
- Never bypass DRM, streaming restrictions, or DJ-software internals.
- Prefer supported macOS frameworks and sandbox-compatible paths.
- Preserve user intent: a manually attached tracklist is never replaced automatically.
- Fail softly when optional context is unavailable; the protected recording remains useful.

## Strategic differentiation

| Alternative | What it does well | SetCatcher's distinct job |
| --- | --- | --- |
| Native DJ-app recording | Captures inside the performance tool | Protects and organizes the completed file across tools |
| Cloud/library products | Protect tracks, metadata, and libraries | Protects the unique recording created by a performance |
| OBS/DAWs | Flexible recording and production | Removes configuration and post-set filing work |
| Automatic single-app recorders | Deep, simple support for one ecosystem | Provides one protection and archive model across DJ apps |
| Finder plus cloud folder | Maximum flexibility | Replaces the manual memory-dependent workflow |

## Business model hypothesis

The invite-only beta is free. The leading post-beta hypothesis is a one-time Mac utility purchase with optional paid major upgrades, because the core value is local and does not incur cloud-storage costs. Pricing remains a research decision until willingness-to-pay interviews and repeated-use data are available.

## Success model

The north-star behavior is **a second real set protected within 30 days of activation**. A second set demonstrates that SetCatcher has moved from a demo into the DJ's working routine.

Supporting measures:

- setup completed without developer help;
- first protected set created successfully;
- source-file integrity confirmed;
- user can explain what SetCatcher does and does not do;
- trust rating of at least 4/5 after first protection;
- actionable support events per protected set trend downward;
- users can find a protected set in under one minute.

## Current strategic risks

- Clean external installation and notarization can undermine trust before product value is experienced.
- Mac-only availability limits the initial market.
- App-audio behavior varies with routing, permissions, sandboxing, and OS support.
- A broad compatibility message can hide meaningful differences between folder, history, and capture support.
- Users may confuse local set protection with full disk backup.
- Adding cloud, publishing, or library-management breadth too early could weaken the core category.
