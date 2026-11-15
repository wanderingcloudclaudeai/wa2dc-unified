// Tests for features ported into wa2dc-unified from sabaris-sps/wa2dc:
// /historysyncdays (HistorySyncDays) and /reorderchannels (ReorderChannels).
import assert from "node:assert/strict";
import test from "node:test";
import { createChannelReorderer } from "../src/channelReorder.js";
import {
	createDefaultSettings,
	MAX_HISTORY_SYNC_DAYS,
	normalizeHistorySyncDays,
	normalizeSettings,
	shouldSyncHistoryChunk,
} from "../src/contracts.js";

const RECENT = 3;
const FULL = 2;
const NOW = 1_800_000_000;
const DAY = 86400;

test("ported settings default to the maintained behaviour", () => {
	const defaults = createDefaultSettings();
	assert.equal(defaults.HistorySyncDays, 0);
	assert.equal(defaults.ReorderChannels, false);
});

test("normalizeSettings sanitizes ported settings", () => {
	assert.equal(normalizeSettings({ HistorySyncDays: 7 }).HistorySyncDays, 7);
	for (const bad of [-1, 1.5, "7", null, MAX_HISTORY_SYNC_DAYS + 1]) {
		assert.equal(
			normalizeSettings({ HistorySyncDays: bad }).HistorySyncDays,
			0,
		);
	}
	assert.equal(normalizeSettings({ ReorderChannels: 1 }).ReorderChannels, true);
	assert.equal(normalizeHistorySyncDays(400, null), null);
});

test("shouldSyncHistoryChunk skips everything when disabled", () => {
	assert.equal(
		shouldSyncHistoryChunk(
			{ syncType: RECENT, oldestMsgInChunkTimestampSec: NOW },
			{ days: 0, allowedSyncTypes: [RECENT], nowSeconds: NOW },
		),
		false,
	);
});

test("shouldSyncHistoryChunk applies the day cut-off per chunk", () => {
	const options = { days: 3, allowedSyncTypes: [RECENT], nowSeconds: NOW };
	const chunk = (oldest, syncType = RECENT) => ({
		syncType,
		oldestMsgInChunkTimestampSec: oldest,
	});
	assert.equal(shouldSyncHistoryChunk(chunk(NOW - 2 * DAY), options), true);
	assert.equal(shouldSyncHistoryChunk(chunk(NOW - 4 * DAY), options), false);
	assert.equal(
		shouldSyncHistoryChunk(chunk(NOW - 2 * DAY, FULL), options),
		false,
	);
	// Protobuf Long timestamps and missing timestamps are both handled.
	assert.equal(
		shouldSyncHistoryChunk(chunk({ toNumber: () => NOW - DAY }), options),
		true,
	);
	assert.equal(shouldSyncHistoryChunk(chunk(undefined), options), true);
});

const makeChannel = (position = 5, extra = {}) => {
	const channel = {
		position,
		calls: 0,
		async setPosition(next) {
			channel.calls += 1;
			channel.position = next;
		},
		...extra,
	};
	return channel;
};

test("channel reorderer is a no-op while disabled", async () => {
	const channel = makeChannel();
	const { moveChannelToTop } = createChannelReorderer({
		fetchChannel: async () => channel,
		isEnabled: () => false,
	});
	assert.equal(await moveChannelToTop("1"), false);
	assert.equal(channel.calls, 0);
});

test("channel reorderer throttles moves per channel", async () => {
	let clock = 0;
	const channels = { a: makeChannel(), b: makeChannel() };
	const { moveChannelToTop } = createChannelReorderer({
		fetchChannel: async (id) => channels[id],
		isEnabled: () => true,
		cooldownMs: 1000,
		now: () => clock,
	});
	assert.equal(await moveChannelToTop("a"), true);
	channels.a.position = 4;
	clock = 500;
	assert.equal(await moveChannelToTop("a"), false);
	assert.equal(await moveChannelToTop("b"), true);
	clock = 1500;
	assert.equal(await moveChannelToTop("a"), true);
	assert.equal(channels.a.calls, 2);
});

test("channel reorderer skips threads, top channels and API errors", async () => {
	const thread = makeChannel(3, { isThread: () => true });
	const top = makeChannel(0);
	const failing = makeChannel(2, {
		async setPosition() {
			throw new Error("rate limited");
		},
	});
	const channels = { thread, top, failing };
	const { moveChannelToTop } = createChannelReorderer({
		fetchChannel: async (id) => channels[id] ?? null,
		isEnabled: () => true,
	});
	assert.equal(await moveChannelToTop("thread"), false);
	assert.equal(await moveChannelToTop("top"), false);
	assert.equal(await moveChannelToTop("failing"), false);
	assert.equal(await moveChannelToTop("missing"), false);
	assert.equal(await moveChannelToTop(null), false);
	assert.equal(thread.calls + top.calls, 0);
});
