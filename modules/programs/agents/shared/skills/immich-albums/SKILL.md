---
name: immich-albums
description: Finds trip or event photos and videos in Immich and organizes them into verified private albums. Use when asked to create or populate an Immich album from a family outing, date range, location, or visual subject; not for server administration.
---

# Immich Albums

Use the connected Executor integration. Preserve originals and keep albums private
unless the user explicitly requests sharing. Distinguish a trip collection from a
curated highlights album; do not silently discard bursts or select only favorites.

## Discover access and tools

1. Read Executor's execution workflow before calling its tools.
2. Search within the `immich` namespace and describe each tool before use. Discover
   the connection address; never hard-code a user's connection, hostname, or IDs.
3. Use `getMyUser` for a read-only authentication check when access is unknown.
   Return only relevant identity/status fields, never credentials or license keys.
4. Branch on `result.ok`. Respect every approval pause, including POST searches:
   obtain the user's response and resume that execution; never bypass approval or
   rerun a paused mutation.

## Find the event

1. Resolve relative dates against the current date and the event's local timezone.
   State the date window being searched. Use explicit offsets and an exclusive
   upper bound at the next day's midnight; ask only if ambiguity affects selection.
2. Describe and use `searchSmart` with a visual query, `takenAfter`, `takenBefore`,
   and `withExif: true`. Smart results are relevance-ranked candidates, not proof
   that every returned asset belongs to the event. A page's `total` need not be
   the full matching-library count. Follow `nextPage` until exhausted when needed.
3. Use `searchAssets` (metadata search) over the date window to enumerate the
   collection, with EXIF and chronological order. Follow all pages; do not create
   an album from only the first page or the top smart-search matches.
4. Keep working data compact: asset ID, type, capture time, camera, GPS/location,
   visibility, and motion-photo relationship. Filter API output before returning
   it; avoid dumping full EXIF, paths, account data, or base64 into chat.
5. Combine location, capture-time clusters, and visual evidence. Do not include
   unrelated home photos, screenshots, travel stops, or adjacent-day events merely
   because they share a weekend. Do not treat a city label alone as park proof.

## Inspect and select

1. Use `viewAsset` thumbnails and `emit(result.data)` to inspect representative
   scenes, boundaries, and uncertain clusters. Inspect uncertain assets individually
   where samples and metadata cannot establish membership. Never claim every image
   was reviewed when only samples were inspected.
2. Compare `localDateTime`, EXIF original time/timezone, and nearby confirmed assets.
   Some videos can have inconsistent timezone metadata. Do not blindly apply a
   fixed offset to every video; establish the discrepancy per camera/cluster before
   using corrected time for selection. Do not rewrite source metadata.
3. Read `getAssetInfo` where needed to obtain `livePhotoVideoId`. Exclude those
   companion video IDs from separate album entries; retain their parent photos and
   standalone videos. Missing thumbnails alone do not prove a video is a companion
   or justify dropping it. Exclude trashed and hidden/locked assets by default.
4. Deduplicate asset IDs, not merely timestamps or similar-looking bursts. Check
   `getAllAlbums` for an existing event album before creating a duplicate. Do not
   modify an existing album unless the user authorized that operation.
5. State the proposed name, photo/video counts, selection basis, and any remaining
   uncertainty before mutation. Ask about genuinely ambiguous event membership or
   whether the user wants a collection versus highlights when it matters.

## Create and verify

1. For an authorized new album, describe and call `createAlbum` with `albumName`,
   `description`, and the selected `assetIds`. Omit shared users; create no public
   link. Do not delete, archive, favorite, edit, or move original assets.
2. Resume connector approvals only after the user's response. On an uncertain
   creation result, check for the saved album before attempting another creation.
3. Read the saved album via `getAlbumInfo`; verify name, count, `shared: false`,
   and `hasSharedLink: false`. Verify membership, not only the creation response:
   prefer an available collection-level asset listing; otherwise `getAllAlbums`
   with each selected `assetId` can confirm membership. Batch reads conservatively.
   Expected-ID membership plus equal saved count establishes the exact selected set.
4. Report the saved album name, actual photo/video counts, privacy, and verification.
   Provide a link only when its service base URL is discovered, not guessed. State
   whether selection was spot-checked or individually reviewed and whether bursts
   remain. If verification fails, report the actual saved state, not success.

## Example

“Make an album from our Sesame Place visit this weekend” → resolve the weekend,
search for Sesame Street characters/theme-park scenes, enumerate weekend metadata,
inspect park-time clusters and boundaries, exclude unrelated events and separate
motion companions, then create and verify a private date-named trip collection.
